import Foundation
import Darwin
import AppKit
import BrowserScopeCore
import BroCleanCLIKit

private let usage = """
BroClean CLI 0.3.0 — local macOS browser cleanup

Usage:
  broclean list [--headless | --automated] [--sort KEY] [--asc | --desc] [--json] [--no-pages]
  broclean inspect PID [--start-time MICROSECONDS] [--json] [--no-pages]
  broclean close PID [--start-time MICROSECONDS] [--force] [--dry-run | --yes] [--json]
  broclean close --headless | --automated [--exclude PID,PID] [--dry-run | --yes] [--json]
  broclean protect PID [--start-time MICROSECONDS] [--json]
  broclean unprotect PID [--start-time MICROSECONDS] [--json]
  broclean --version | --help

Sort keys: name, type, browser, memory, pages, pid, age. Unknown values sort last.
No command means list. --no-pages skips CDP requests for a faster snapshot.

Closing freezes a plan and revalidates PID + start time before signalling.
Use --dry-run to preview; otherwise confirm interactively, or pass --yes explicitly.
--force is a separate single-instance action. It never follows automatically after a normal close.
Bulk cleanup skips protected and non-temporary profiles. A single close can still target
an individually selected browser with a normal profile. No profiles or browsing data are deleted.
Protection is shared with the current menu-bar app and survives restarts.
JSON stdout is schema-versioned; prompts/errors go to stderr.
Exit codes: 0 success/cancelled, 1 runtime error, 2 usage/confirmation required,
            3 target not found/identity changed, 4 close incomplete/refused/restarted.
"""

struct BrowserRow: Encodable {
    let pid: Int32
    let startMicroseconds: UInt64
    let name: String
    let browser: String
    let mode: String
    let automated: Bool
    let likelyPersonalBrowser: Bool
    let source: SourceAttribution
    let profile: String
    let memory: MemoryReading
    let pages: PageReading
    let protectedFromBulk: Bool
    let memberPIDs: [Int32]
    let headlessExclusion: String?
    let automatedExclusion: String?
    init(_ instance: BrowserInstance, pages: PageReading, protected: Bool) {
        pid = instance.id.pid; startMicroseconds = instance.id.startMicroseconds
        name = instance.displayTitle; browser = instance.family.rawValue; mode = instance.mode.rawValue
        automated = instance.automated; likelyPersonalBrowser = instance.likelyPersonalBrowser
        source = instance.source; profile = instance.profileKind.rawValue; memory = instance.memory
        self.pages = pages; protectedFromBulk = protected; memberPIDs = instance.members.map(\.identity.pid)
        headlessExclusion = protected ? "Protected from bulk cleanup" : instance.bulkExclusion
        automatedExclusion = protected ? "Protected from bulk cleanup" : instance.bulkExclusion(for: .automated)
    }
}
struct Output: Encodable {
    let schemaVersion = 1
    let command: String
    var dryRun = false
    var cancelled = false
    var instances: [BrowserRow] = []
    var skipped: [SkippedInstance] = []
    var results: [CloseResult] = []
}

@main
struct BroCleanCLI {
    static func stderr(_ text: String) { FileHandle.standardError.write(Data(text.utf8)) }
    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    static func main() async {
        do { exit(try await run(Options.parse(Array(CommandLine.arguments.dropFirst())))) }
        catch {
            let code = (error as? CLIError)?.code ?? 1
            if CommandLine.arguments.contains("--json") {
                struct Failure: Encodable { let error: String; let exitCode: Int32 }
                stderr((try? encode(Failure(error: error.localizedDescription, exitCode: code))) ?? "{\"error\":\"Encoding failed\"}")
                stderr("\n")
            } else { stderr("Error: \(error.localizedDescription)\n") }
            exit(code)
        }
    }
    static func rows(_ instances: [BrowserInstance], readings: [ProcessIdentity: PageReading], kept: Set<ProcessIdentity>) -> [BrowserRow] {
        instances.map { BrowserRow($0, pages: readings[$0.id] ?? .init(reason: "Not sampled for this command."), protected: kept.contains($0.id)) }
    }
    static func table(_ rows: [BrowserRow]) -> String {
        guard !rows.isEmpty else { return "No matching browser instances.\n" }
        let data = [["PID", "NAME / SOURCE", "TYPE", "MEMORY", "PAGES", "PROFILE", "KEEP"]] + rows.map {
            [String($0.pid), $0.name, $0.mode, $0.memory.formatted + ($0.memory.partial ? "*" : ""),
             $0.pages.count.map(String.init) ?? "—", $0.profile, $0.protectedFromBulk ? "yes" : ""]
        }
        let widths = (0..<data[0].count).map { column in data.map { $0[column].count }.max()! }
        return data.map { row in row.enumerated().map { index, text in text.padding(toLength: widths[index], withPad: " ", startingAt: 0) }.joined(separator: "  ") }.joined(separator: "\n") + "\n"
    }
    static func run(_ options: Options) async throws -> Int32 {
        if options.command == .help { print(usage); return 0 }
        if options.command == .version { print("broclean 0.3.0"); return 0 }
        let all = BrowserResolver().resolve(ProcessScanner().scan())
        let store = InstanceProtectionStore()
        var kept = try store.load()
        var selected = all
        if let pid = options.pid {
            guard let instance = all.first(where: { $0.id.pid == pid }) else { throw CLIError("Browser PID \(pid) not found.", code: 3) }
            if let start = options.startTime, instance.id.startMicroseconds != start { throw CLIError("Process identity changed; no action taken.", code: 3) }
            selected = [instance]
        } else if let scope = options.scope {
            selected = all.filter { scope == .headless ? $0.mode == .headless : $0.automated }
        }
        if options.command == .protect || options.command == .unprotect {
            let instance = selected[0]
            _ = try SignalGateway().validate(instance.root)
            try store.set(instance.id, protected: options.command == .protect)
            kept = try store.load()
            let output = Output(command: options.command.rawValue, instances: rows(selected, readings: [:], kept: kept))
            if options.json { print(try encode(output)) }
            else { print("PID \(instance.id.pid): \(options.command == .protect ? "protected from bulk cleanup" : "bulk protection removed").") }
            return 0
        }
        if options.command == .close {
            let plan = try ClosePlan.make(instances: all, options: options, protected: kept)
            var output = Output(command: "close", dryRun: options.dryRun, instances: rows(plan.targets, readings: [:], kept: kept), skipped: plan.skipped)
            let description = "\(options.force ? "FORCE QUIT" : "CLOSE") \(plan.targets.count) instance(s)\n" + table(output.instances)
                + plan.skipped.map { "Skipped PID \($0.pid): \($0.reason)\n" }.joined()
            if options.dryRun || plan.targets.isEmpty {
                if options.json { print(try encode(output)) }
                else { print((options.dryRun ? "DRY RUN — no signals will be sent.\n" : "") + description, terminator: "") }
                return plan.targets.isEmpty && options.pid != nil && !plan.skipped.isEmpty ? 4 : 0
            }
            if !options.yes {
                guard isatty(STDIN_FILENO) == 1 else { throw CLIError("Confirmation required. Use --dry-run to preview or explicitly pass --yes.") }
                stderr(description + "Active work may be interrupted. Type yes to continue: ")
                guard readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes" else {
                    output.cancelled = true
                    if options.json { print(try encode(output)) } else { print("Cancelled. No signals sent.") }
                    return 0
                }
            } else if !options.json { print(description, terminator: "") }
            for instance in plan.targets {
                let graceful: (@Sendable (ProcessRecord) async -> Bool)?
                if instance.mode == .headed {
                    graceful = { record in await MainActor.run {
                        guard (try? SignalGateway().validate(record)) != nil else { return false }
                        return NSRunningApplication(processIdentifier: record.identity.pid)?.terminate() ?? false
                    } }
                } else { graceful = nil }
                let result = await TerminationCoordinator().close(instance, force: options.force,
                    bulk: options.scope != nil, bulkScope: options.scope ?? .headless, graceful: graceful)
                output.results.append(result)
            }
            if options.json { print(try encode(output)) }
            else { for result in output.results { print("PID \(result.identity.pid): \(result.status.rawValue) — \(result.message)") } }
            return output.results.allSatisfy { $0.status == .closed } ? 0 : 4
        }
        var readings: [ProcessIdentity: PageReading] = [:]
        if !options.noPages {
            for instance in selected { readings[instance.id] = await PageProvider().read(instance) }
        }
        selected = BrowserSorter.sorted(selected, pages: readings, key: options.sort, ascending: options.ascending)
        let output = Output(command: options.command.rawValue, instances: rows(selected, readings: readings, kept: kept))
        if options.json { print(try encode(output)) }
        else if options.command == .inspect, let row = output.instances.first {
            print(table([row]), terminator: "")
            print("Identity: PID \(row.pid), start \(row.startMicroseconds) microseconds\nBrowser: \(row.browser)\nMembers: \(row.memberPIDs.map(String.init).joined(separator: ", "))")
            print("Pages: \(row.pages.reason ?? "Accessible top-level page count")")
            print("Headless cleanup: \(row.headlessExclusion ?? "Eligible")\nAutomated cleanup: \(row.automatedExclusion ?? "Eligible")")
            if let pid = row.source.launcherPID { print("Launcher: \(pid)\(row.source.sharedLauncher ? " (shared)" : "")") }
            for evidence in row.source.evidence { print("Evidence: \(evidence)") }
        } else {
            print(table(output.instances), terminator: "")
            print("\(selected.count) instance(s). Memory = RSS sum; * partial. — = unknown. Source attribution is inferred.")
        }
        return 0
    }
}
