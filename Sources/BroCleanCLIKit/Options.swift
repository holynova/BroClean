import Foundation
import BrowserScopeCore

public struct CLIError: Error, LocalizedError, Sendable {
    public let message: String
    public let code: Int32
    public init(_ message: String, code: Int32 = 2) { self.message = message; self.code = code }
    public var errorDescription: String? { message }
}
public enum Command: String, Sendable { case list, inspect, close, protect, unprotect, help, version }
public struct Options: Sendable {
    public var command: Command = .list
    public var pid: Int32?
    public var scope: BulkCloseScope?
    public var sort: BrowserSortKey = .type
    public var ascending = true
    public var json = false
    public var noPages = false
    public var yes = false
    public var dryRun = false
    public var force = false
    public var startTime: UInt64?
    public var excluded: Set<Int32> = []
    public static func parse(_ arguments: [String]) throws -> Options {
        var result = Options(), args = arguments
        if args.first == "--help" || args.first == "-h" { result.command = .help; return result }
        if args.first == "--version" { result.command = .version; return result }
        if let first = args.first, !first.hasPrefix("-") {
            guard let command = Command(rawValue: first) else { throw CLIError("Unknown command: \(first). Use broclean --help.") }
            result.command = command; args.removeFirst()
        }
        var seen = Set<String>(), positionals: [String] = []
        var index = 0
        while index < args.count {
            let flag = args[index]; index += 1
            if flag == "--help" || flag == "-h" { result.command = .help; return result }
            if !flag.hasPrefix("-") { positionals.append(flag); continue }
            guard seen.insert(flag).inserted else { throw CLIError("Duplicate option: \(flag)") }
            func value() throws -> String {
                guard index < args.count, !args[index].hasPrefix("--") else { throw CLIError("Missing value for \(flag)") }
                defer { index += 1 }; return args[index]
            }
            switch flag {
            case "--json": result.json = true
            case "--no-pages": result.noPages = true
            case "--yes", "-y": result.yes = true
            case "--dry-run": result.dryRun = true
            case "--force": result.force = true
            case "--headless", "--automated":
                guard result.scope == nil else { throw CLIError("Choose only one of --headless or --automated.") }
                result.scope = flag == "--headless" ? .headless : .automated
            case "--asc", "--desc":
                guard !seen.contains(flag == "--asc" ? "--desc" : "--asc") else { throw CLIError("Choose --asc or --desc, not both.") }
                result.ascending = flag == "--asc"
            case "--sort":
                let name = try value()
                guard let key = BrowserSortKey.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) else { throw CLIError("Invalid sort key: \(name)") }
                result.sort = key
            case "--start-time":
                guard let time = UInt64(try value()), time > 0 else { throw CLIError("--start-time requires positive kernel microseconds.") }
                result.startTime = time
            case "--exclude":
                for text in try value().split(separator: ",", omittingEmptySubsequences: false) {
                    guard let pid = Int32(text), pid > 1 else { throw CLIError("--exclude requires comma-separated browser PIDs.") }
                    result.excluded.insert(pid)
                }
            default: throw CLIError("Unknown option: \(flag)")
            }
        }
        if !positionals.isEmpty {
            guard positionals.count == 1, let pid = Int32(positionals[0]), pid > 1 else { throw CLIError("Expected one browser PID greater than 1.") }
            result.pid = pid
        }
        let closing = result.command == .close
        if !closing && (result.yes || result.force || result.dryRun || !result.excluded.isEmpty) { throw CLIError("Close options can only be used with close.") }
        if [.inspect, .protect, .unprotect].contains(result.command) && result.pid == nil { throw CLIError("\(result.command.rawValue) requires a browser PID.") }
        if result.command == .list && result.pid != nil { throw CLIError("Use inspect PID for a single browser.") }
        if closing && ((result.pid == nil) == (result.scope == nil)) { throw CLIError("close requires either PID or --headless/--automated.") }
        if result.scope != nil && ![.list, .close].contains(result.command) { throw CLIError("Scope filters are supported only by list and close.") }
        if result.pid != nil && result.scope != nil { throw CLIError("Do not combine PID and a bulk scope.") }
        if result.force && result.pid == nil { throw CLIError("--force is allowed only for an explicit single PID.") }
        if result.startTime != nil && result.pid == nil { throw CLIError("--start-time requires an explicit PID.") }
        if !result.excluded.isEmpty && result.scope == nil { throw CLIError("--exclude requires a bulk close scope.") }
        if ![.list,.inspect].contains(result.command) && (seen.contains("--sort") || seen.contains("--asc") || seen.contains("--desc") || result.noPages) { throw CLIError("Sorting and --no-pages are list/inspect options.") }
        return result
    }
}

public struct SkippedInstance: Encodable, Sendable {
    public let pid: Int32
    public let reason: String
    public init(pid: Int32, reason: String) { self.pid = pid; self.reason = reason }
}
public struct ClosePlan: Sendable {
    public let targets: [BrowserInstance]
    public let skipped: [SkippedInstance]
    public static func make(instances: [BrowserInstance], options: Options, protected: Set<ProcessIdentity>) throws -> ClosePlan {
        if let pid = options.pid {
            guard let instance = instances.first(where: { $0.id.pid == pid }) else { throw CLIError("Browser PID \(pid) not found. Refresh the list.", code: 3) }
            if let expected = options.startTime, expected != instance.id.startMicroseconds { throw CLIError("PID identity changed; no process was selected.", code: 3) }
            if let reason = instance.protectedReason { return .init(targets: [], skipped: [.init(pid: pid, reason: reason)]) }
            return .init(targets: [instance], skipped: [])
        }
        guard let scope = options.scope else { throw CLIError("Missing close target.") }
        var targets: [BrowserInstance] = [], skipped: [SkippedInstance] = []
        for instance in instances where scope == .headless ? instance.mode == .headless : instance.automated {
            let reason = options.excluded.contains(instance.id.pid) ? "Excluded by --exclude" : protected.contains(instance.id) ? "Protected from bulk cleanup" : instance.bulkExclusion(for: scope)
            if let reason { skipped.append(.init(pid: instance.id.pid, reason: reason)) }
            else { targets.append(instance) }
        }
        return .init(targets: targets, skipped: skipped)
    }
}
