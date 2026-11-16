import Foundation
import Darwin

public struct BrowserResolver: Sendable {
    public init() {}
    public static func family(path: String) -> BrowserFamily? {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        switch name {
        case "google chrome", "google chrome beta", "google chrome dev", "google chrome canary", "chrome": return .chrome
        case "google chrome for testing": return .chromeTesting
        case "chromium", "headless_shell", "chrome-headless-shell": return .chromium
        case "microsoft edge", "microsoft edge beta", "microsoft edge dev", "microsoft edge canary", "msedge": return .edge
        case "safari": return .safari
        case "firefox": return .firefox
        default: return nil
        }
    }
    public static func argument(_ flag: String, in args: [String]) -> String? {
        if let arg = args.first(where: { $0.hasPrefix(flag + "=") }) { return String(arg.dropFirst(flag.count + 1)) }
        if let i = args.firstIndex(of: flag), i + 1 < args.count, !args[i + 1].hasPrefix("-") { return args[i + 1] }
        return nil
    }
    public static func profileKind(path: String?, family: BrowserFamily, argsKnown: Bool) -> ProfileKind {
        guard let path, path.hasPrefix("/") else {
            return argsKnown && family != .chromium ? .standard : .unknown
        }
        let p = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
        let standard = ["/library/application support/google/chrome", "/library/application support/microsoft edge",
                        "/library/application support/firefox", "/library/safari"]
        if standard.contains(where: { p.hasSuffix($0) || p.contains($0 + "/") }) { return .standard }
        let temporaryRoot = p.hasPrefix("/tmp/") || p.hasPrefix("/private/tmp/") || p.hasPrefix("/var/folders/") || p.hasPrefix("/private/var/folders/")
        let name = URL(fileURLWithPath: p).lastPathComponent
        let markers = ["playwright_", "puppeteer_dev_chrome_profile-", "puppeteer-", "rod-", "browser-scope-test-"]
        if temporaryRoot && markers.contains(where: { name.hasPrefix($0) }) { return .temporary }
        return .custom
    }
    private func software(_ process: ProcessRecord) -> String? {
        let p = process.path.lowercased()
        let executable = URL(fileURLWithPath: p).lastPathComponent
        if executable == "codex" || p.contains("/codex.app/") { return "Codex" }
        if executable == "claude" || p.contains("/claude.app/") { return "Claude" }
        if p.contains("/chatgpt.app/") { return "ChatGPT" }
        if p.contains("/cursor.app/") { return "Cursor" }
        if p.contains("/windsurf.app/") { return "Windsurf" }
        return nil
    }
    private func framework(_ process: ProcessRecord) -> String? {
        let tokens = ([process.path] + (process.arguments ?? [])).filter { !$0.contains("://") }.map { $0.lowercased() }
        if tokens.contains(where: { $0.contains("playwright") }) { return "Playwright" }
        if tokens.contains(where: { $0.contains("puppeteer") }) { return "Puppeteer" }
        if tokens.contains(where: { $0.contains("chromedriver") || $0.contains("geckodriver") || $0.contains("msedgedriver") }) { return "WebDriver" }
        if tokens.contains(where: { $0.contains("selenium") }) { return "Selenium" }
        if tokens.contains(where: { $0.contains("agent-browser") }) { return "agent-browser" }
        if tokens.contains(where: { $0.contains("/rod/") || $0.contains("rod-") }) { return "Rod" }
        return nil
    }
    public func resolve(_ snapshot: ProcessSnapshot, currentPID: Int32 = getpid(), uid: UInt32 = getuid()) -> [BrowserInstance] {
        let records = snapshot.records
        let index = Dictionary(uniqueKeysWithValues: records.map { ($0.identity.pid, $0) })
        let children = Dictionary(grouping: records, by: \.parentPID)
        var protectedPIDs: Set<Int32> = [0, 1, currentPID]
        var parent = index[currentPID]?.parentPID
        while let pid = parent, protectedPIDs.insert(pid).inserted { parent = index[pid]?.parentPID }
        let roots = records.filter { p in
            Self.family(path: p.path) != nil && !(p.arguments ?? []).contains(where: {
                $0.hasPrefix("--type=") || $0 == "-contentproc"
            })
        }
        let rootIDs = Set(roots.map { $0.identity.pid })
        var instances = roots.compactMap { root -> BrowserInstance? in
            guard let family = Self.family(path: root.path), root.uid == uid else { return nil }
            let args = root.arguments ?? []
            let shell = ["headless_shell", "chrome-headless-shell"].contains(URL(fileURLWithPath: root.path).lastPathComponent)
            let headless = shell || args.contains { $0 == "--headless" || $0.hasPrefix("--headless=") || $0 == "-headless" }
            let mode: BrowserMode = headless ? .headless : (root.arguments == nil ? .unknown : .headed)
            let profile = Self.argument("--user-data-dir", in: args) ?? Self.argument("-profile", in: args)
            let profileKind = Self.profileKind(path: profile, family: family, argsKnown: root.arguments != nil)
            var source = SourceAttribution()
            var chain: [ProcessRecord] = [root]
            var ppid = root.parentPID
            var visited: Set<Int32> = [root.identity.pid]
            while let p = index[ppid], visited.insert(ppid).inserted, chain.count < 32 {
                chain.append(p); ppid = p.parentPID
            }
            for p in chain {
                if source.framework == nil, let f = framework(p) {
                    source.framework = f
                    source.evidence.append("\(f) fingerprint in \(p.identity.pid == root.identity.pid ? "browser arguments" : "ancestor metadata")")
                    if p.identity != root.identity {
                        source.launcherPID = p.identity.pid
                        source.launcherName = f
                    }
                }
                if source.launcherPID == nil, p.identity != root.identity, let f = framework(p) {
                    source.launcherPID = p.identity.pid; source.launcherName = f
                }
                if source.software == nil, p.identity != root.identity, let s = software(p) {
                    source.software = s; source.evidence.append("\(s) ancestor, PID \(p.identity.pid)")
                }
            }
            if source.software == nil, source.framework == nil,
               chain.dropFirst().contains(where: { ["Terminal", "iTerm2", "Ghostty", "Warp"].contains(URL(fileURLWithPath: $0.path).lastPathComponent) }) {
                source.software = "Terminal"; source.evidence.append("Terminal application in parent chain")
            }
            if headless { source.evidence.append(shell ? "Headless shell executable" : "Explicit headless flag") }
            if profileKind == .temporary { source.evidence.append("Recognized isolated temporary profile") }
            let pipe = args.contains("--remote-debugging-pipe")
            let port = Self.argument("--remote-debugging-port", in: args).flatMap(Int.init)
            if pipe { source.evidence.append("Debugging pipe (not a TCP endpoint)") }
            if port != nil { source.evidence.append("Remote debugging port configured") }
            let automated = source.framework != nil || args.contains("--enable-automation") || profileKind == .temporary
            var members = [root]
            var queue = children[root.identity.pid] ?? []
            var seen: Set<Int32> = [root.identity.pid]
            let groupingPath = root.launchPath.flatMap { Self.family(path: $0) == family ? $0 : nil } ?? root.path
            let bundlePrefix: String
            if let range = groupingPath.range(of: ".app/") { bundlePrefix = String(groupingPath[..<range.upperBound]) }
            else { bundlePrefix = URL(fileURLWithPath: groupingPath).deletingLastPathComponent().path + "/" }
            while !queue.isEmpty {
                let child = queue.removeFirst()
                guard seen.insert(child.identity.pid).inserted, !rootIDs.contains(child.identity.pid) else { continue }
                // Native messaging hosts and unrelated descendants do not belong to a browser close plan.
                guard child.uid == root.uid, child.path.hasPrefix(bundlePrefix), !protectedPIDs.contains(child.identity.pid) else { continue }
                members.append(child)
                queue.append(contentsOf: children[child.identity.pid] ?? [])
            }
            let readings = members.compactMap(\.residentBytes)
            let memory = MemoryReading(bytes: readings.isEmpty ? nil : readings.reduce(0, +),
                                       partial: readings.count != members.count || family == .safari || (root.path.contains("code_sign_clone") && root.launchPath == nil),
                                       measuredProcesses: readings.count, totalProcesses: members.count)
            return BrowserInstance(root: root, family: family, mode: mode, automated: automated,
                                   members: members.sorted { $0.identity.pid < $1.identity.pid }, source: source,
                                   profileKind: profileKind, profilePath: profile, memory: memory, debugPort: port,
                                   debuggingPipe: pipe, protectedReason: protectedPIDs.contains(root.identity.pid) ? "Protected application or ancestor" : nil)
        }
        let launcherCounts = Dictionary(grouping: instances.compactMap { $0.source.launcherPID }, by: { $0 }).mapValues(\.count)
        for i in instances.indices {
            if let pid = instances[i].source.launcherPID { instances[i].source.sharedLauncher = (launcherCounts[pid] ?? 0) > 1 }
        }
        return instances.sorted {
            if ($0.mode == .headless) != ($1.mode == .headless) { return $0.mode == .headless }
            return $0.id.startMicroseconds < $1.id.startMicroseconds
        }
    }
}
