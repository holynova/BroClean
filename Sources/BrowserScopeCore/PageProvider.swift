import Foundation

private final class NoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

public struct PageProvider: Sendable {
    public init() {}
    public static func countTargets(_ data: Data) throws -> Int {
        struct Target: Decodable { let id: String; let type: String; let url: String }
        let targets = try JSONDecoder().decode([Target].self, from: data)
        return Set(targets.filter {
            $0.type == "page" && !$0.url.hasPrefix("chrome-extension:") && !$0.url.hasPrefix("devtools:")
        }.map(\.id)).count
    }
    public func read(_ instance: BrowserInstance) async -> PageReading {
        guard [.chrome, .chromium, .chromeTesting, .edge].contains(instance.family) else {
            return .init(reason: "Page enumeration is not available for this browser.")
        }
        var port = instance.debugPort
        if port == 0, let path = instance.profilePath, path.hasPrefix("/"), instance.profileKind != .standard {
            let file = URL(fileURLWithPath: path).appendingPathComponent("DevToolsActivePort")
            if let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey]),
               values.isSymbolicLink != true, (values.fileSize ?? 0) < 4096,
               let contents = try? String(contentsOf: file, encoding: .utf8) {
                port = contents.split(separator: "\n").first.flatMap { Int($0) }
            }
        }
        guard let port, (1...65535).contains(port) else {
            return .init(reason: instance.debuggingPipe ? "This browser uses a private debugging pipe. No independent page endpoint is available." : "No accessible debugging endpoint. Browser configuration was not changed.")
        }
        let scanner = ProcessScanner()
        guard scanner.read(pid: instance.id.pid)?.identity == instance.id,
              scanner.ownsListeningPort(pid: instance.id.pid, port: port) else {
            return .init(reason: "Could not verify that this browser owns the debugging endpoint.")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        configuration.connectionProxyDictionary = [:]
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        guard let url = URL(string: "http://127.0.0.1:\(port)/json/list") else { return .init(reason: "Invalid endpoint.") }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 2_000_000 else {
                return .init(reason: "Browser endpoint did not provide a valid page list.")
            }
            guard scanner.read(pid: instance.id.pid)?.identity == instance.id else { return .init(reason: "Browser exited during page enumeration.") }
            return .init(count: try Self.countTargets(data))
        } catch {
            return .init(reason: "Page endpoint is unavailable or timed out.")
        }
    }
}
