import Foundation
import Darwin
import BrowserScopeCore

@main
struct Diagnostics {
    struct Entry: Encodable {
        let pid: Int32
        let startMicroseconds: UInt64
        let browser: String
        let mode: String
        let source: SourceAttribution
        let profile: String
        let memory: MemoryReading
        let pages: PageReading
        let members: [Int32]
        let bulkExclusion: String?
    }
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data(("Error: " + error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
    static func run() async throws {
        let instances = BrowserResolver().resolve(ProcessScanner().scan())
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "close-test",
           let pid = Int32(CommandLine.arguments[2]), let start = UInt64(CommandLine.arguments[3]) {
            guard let instance = instances.first(where: { $0.id.pid == pid && $0.id.startMicroseconds == start }),
                  instance.mode == .headless, instance.profileKind == .temporary,
                  let path = instance.profilePath, URL(fileURLWithPath: path).lastPathComponent.hasPrefix("browser-scope-test-") else {
                throw NSError(domain: "BrowserScope", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an identified disposable test browser."])
            }
            let result = await TerminationCoordinator().close(instance, bulk: true)
            print(String(decoding: try JSONEncoder().encode(result), as: UTF8.self))
            return
        }
        var entries: [Entry] = []
        for instance in instances {
            entries.append(.init(pid: instance.id.pid, startMicroseconds: instance.id.startMicroseconds,
                browser: instance.family.rawValue, mode: instance.mode.rawValue, source: instance.source,
                profile: instance.profileKind.rawValue, memory: instance.memory, pages: await PageProvider().read(instance),
                members: instance.members.map { $0.identity.pid }, bulkExclusion: instance.bulkExclusion))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(entries), as: UTF8.self))
    }
}
