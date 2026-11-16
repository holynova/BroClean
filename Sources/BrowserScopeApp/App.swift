import AppKit
import SwiftUI
import ServiceManagement
import BrowserScopeCore

@MainActor
final class BrowserModel: ObservableObject {
    @Published var instances: [BrowserInstance] = []
    @Published var pages: [ProcessIdentity: PageReading] = [:]
    @Published var filter = UserDefaults.standard.string(forKey: "browserFilter") ?? "All" {
        didSet { UserDefaults.standard.set(filter, forKey: "browserFilter") }
    }
    @Published var sortKey = BrowserSortKey(rawValue: UserDefaults.standard.string(forKey: "sortKey") ?? "Type") ?? .type {
        didSet { UserDefaults.standard.set(sortKey.rawValue, forKey: "sortKey") }
    }
    @Published var sortAscending = UserDefaults.standard.object(forKey: "sortAscending") as? Bool ?? true {
        didSet { UserDefaults.standard.set(sortAscending, forKey: "sortAscending") }
    }
    @Published var githubURL = UserDefaults.standard.string(forKey: "githubURL") ?? Bundle.main.object(forInfoDictionaryKey: "BroCleanGitHubURL") as? String ?? ""
    @Published var editingRepository = false
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0" }
    func selectSort(_ key: BrowserSortKey) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = ![.memory, .pages, .age].contains(key) }
    }
    @Published var selected: ProcessIdentity?
    @Published var kept: Set<ProcessIdentity> = []
    @Published var busy = false
    @Published var operationLabel = ""
    @Published var stopRequested = false
    @Published var savingProtection = false
    private var protectionRevision = 0
    var dismissPanel: (() -> Void)?
    @Published var refreshing = false
    @Published var results: [CloseResult] = []
    @Published var notice: String?
    @Published var pending: CloseAction?
    var visible = false
    var sleeping = false
    let demo: Bool
    init(demo: Bool = CommandLine.arguments.contains("--demo")) { self.demo = demo }
    var monitor: Task<Void, Never>?
    var filtered: [BrowserInstance] {
        BrowserSorter.sorted(instances.filter { filter == "All" || (filter == "Headless" ? $0.mode == .headless : $0.automated) }, pages: pages, key: sortKey, ascending: sortAscending)
    }
    func eligible(_ scope: BulkCloseScope) -> [BrowserInstance] {
        instances.filter { $0.bulkExclusion(for: scope) == nil && !kept.contains($0.id) }
    }
    var totalMemory: String {
        let values = instances.compactMap(\.memory.bytes)
        guard !values.isEmpty else { return instances.isEmpty ? "0 MB" : "—" }
        let partial = values.count != instances.count || instances.contains { $0.memory.partial }
        return MemoryReading(bytes: values.reduce(0,+), partial: partial, measuredProcesses: 0, totalProcesses: 0).formatted + (partial ? "+" : "")
    }
    func requestGroup(_ group: BrowserGroup) {
        let plan = GroupClosePlan(visible: filtered, group: group, protected: kept)
        guard !plan.targets.isEmpty else { return }
        pending = CloseAction(targets: plan.targets, force: false, scope: plan.scope,
            skipped: plan.skipped, groupName: group.rawValue, respectsProtection: true)
    }
    func start() {
        if demo { loadDemo(); return }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !sleeping { await refresh() }
                try? await Task.sleep(for: .seconds(visible ? 2 : 10))
            }
        }
    }
    func refresh() async {
        guard !refreshing, !demo else { return }
        refreshing = true
        let found = await Task.detached(priority: .utility) { BrowserResolver().resolve(ProcessScanner().scan()) }.value
        instances = found
        let loadedRevision = protectionRevision
        let protection = await Task.detached { try? InstanceProtectionStore().load() }.value
        if let protection, !savingProtection, loadedRevision == protectionRevision { kept = protection }
        else if protection == nil { notice = "Could not read protection settings. Bulk cleanup will refuse to proceed." }
        let readings = await Task.detached(priority: .utility) {
            var values: [ProcessIdentity: PageReading] = [:]
            for instance in found { values[instance.id] = await PageProvider().read(instance) }
            return values
        }.value
        pages = readings
        refreshing = false
    }
    func request(_ targets: [BrowserInstance], force: Bool = false, scope: BulkCloseScope? = nil) {
        pending = CloseAction(targets: targets, force: force, scope: scope,
            skipped: scope.map { scope in
                instances.filter { (scope == .headless ? $0.mode == .headless : $0.automated) && ($0.bulkExclusion(for: scope) != nil || kept.contains($0.id)) }
                    .map { "PID \($0.id.pid): \(kept.contains($0.id) ? "Kept by you" : $0.bulkExclusion(for: scope)!)" }
            } ?? [])
    }
    func execute(_ action: CloseAction) {
        guard !busy else { return }
        busy = true
        stopRequested = false
        operationLabel = "Preparing close…"
        Task {
            if demo {
                let ids = Set(action.targets.filter { !action.respectsProtection || !kept.contains($0.id) }.map(\.id))
                instances.removeAll { ids.contains($0.id) }
                notice = "Demo only — no processes were closed."
                busy = false
                return
            }
            results = []
            for (index, instance) in action.targets.enumerated() {
                if stopRequested { notice = "Stopped. Remaining browsers were not closed."; break }
                operationLabel = "Closing \(index + 1) of \(action.targets.count) · \(instance.displayTitle)"
                if action.respectsProtection {
                    let protected = await Task.detached { InstanceProtectionStore().protectsBulk(instance.id) }.value
                    if protected {
                        results.append(.init(identity: instance.id, status: .refused, message: "Protected from group cleanup, or protection settings are unreadable."))
                        continue
                    }
                }
                let graceful: (@Sendable (ProcessRecord) async -> Bool)?
                if instance.mode == .headed {
                    graceful = { record in
                        await MainActor.run {
                            guard (try? SignalGateway().validate(record)) != nil else { return false }
                            return NSRunningApplication(processIdentifier: record.identity.pid)?.terminate() ?? false
                        }
                    }
                } else { graceful = nil }
                let result = await Task.detached(priority: .userInitiated) {
                    await TerminationCoordinator().close(instance, force: action.force, bulk: action.scope != nil, bulkScope: action.scope ?? .headless, graceful: graceful)
                }.value
                results.append(result)
            }
            busy = false
            await refresh()
        }
    }
    func toggleProtection(_ instance: BrowserInstance) {
        let protect = !kept.contains(instance.id)
        if demo {
            if protect { kept.insert(instance.id) } else { kept.remove(instance.id) }
            return
        }
        guard !savingProtection else { return }
        savingProtection = true
        protectionRevision += 1
        Task {
            let result = await Task.detached { () -> (Set<ProcessIdentity>?, String?) in
                do {
                    try InstanceProtectionStore().set(instance.id, protected: protect)
                    return (try InstanceProtectionStore().load(), nil)
                } catch { return (nil, error.localizedDescription) }
            }.value
            if let values = result.0 { kept = values }
            if let error = result.1 { notice = "Could not save protection: \(error)" }
            protectionRevision += 1
            savingProtection = false
        }
    }

    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            notice = SMAppService.mainApp.status == .requiresApproval ? "Allow BroClean in System Settings → Login Items." : "Login item updated."
        } catch { notice = error.localizedDescription }
    }
    func loadDemo() {
        let now = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        var records: [ProcessRecord] = []
        let sources = ["/Applications/Codex.app/Contents/MacOS/Codex", "/Applications/Claude.app/Contents/MacOS/Claude", "/usr/local/bin/node", "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"]
        for n in 0..<4 {
            records.append(.init(pid: Int32(700+n), start: now-4_000_000_000, parentPID: 1, uid: getuid(), path: sources[n], arguments: [sources[n], "playwright/cli.js"]))
            records.append(.init(pid: Int32(800+n), start: now-UInt64(600+n*370)*1_000_000, parentPID: Int32(700+n), uid: getuid(), path: chrome, arguments: [chrome,"--user-data-dir=/tmp/playwright_chromiumdev_profile_demo\(n)"] + (n == 3 ? [] : ["--headless=new"]), residentBytes: UInt64([420,185,890,245][n])*1_000_000))
        }
        records.append(.init(pid: 900, start: now-8_000_000_000, parentPID: 1, uid: getuid(), path: "/Applications/Safari.app/Contents/MacOS/Safari", arguments: ["Safari"], residentBytes: 630_000_000))
        instances = BrowserResolver().resolve(.init(records: records))
        kept = Set(instances.filter { $0.id.pid == 801 }.map(\.id))
        notice = nil
        results = []
        for (n, instance) in instances.enumerated() { pages[instance.id] = .init(count: instance.family == .safari ? nil : [3,1,8,2][n % 4], reason: instance.family == .safari ? "Safari page counts are not available in this MVP." : nil) }
    }
}
struct CloseAction: Identifiable {
    let id = UUID()
    let targets: [BrowserInstance]
    let force: Bool
    let scope: BulkCloseScope?
    let skipped: [String]
    var groupName: String? = nil
    var respectsProtection = false
    var title: String { if let groupName { return "Close \(groupName.lowercased()) group?" }; return "\(force ? "Force quit" : "Close") \(targets.count == 1 ? targets[0].family.rawValue : "\(targets.count) \(scope?.rawValue ?? "") browsers")?" }
    var message: String {
        let list = targets.map { "\($0.displayTitle) · \($0.usageLabel ?? $0.family.rawValue) · PID \($0.id.pid)" }.joined(separator: "\n")
        return list + "\n\nActive work may be interrupted. " + (force ? "Force quit immediately stops the verified browser processes." : "A normal termination request will be sent. Force quit is always a separate action.") + (skipped.isEmpty ? "" : "\n\nSkipped:\n" + skipped.joined(separator: "\n"))
    }
}

struct RepositorySettings: View {
    @ObservedObject var model: BrowserModel
    @State private var value = ""
    static func validURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "github.com", url.user == nil, url.password == nil,
              url.path.split(separator: "/").count == 2 else { return nil }
        return url
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GitHub repository").font(.headline)
            Text("Enter the repository URL for BroClean.").font(.caption).foregroundStyle(.secondary)
            TextField("https://github.com/owner/repository", text: $value).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { model.editingRepository = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    guard let url = Self.validURL(value) else { return }
                    model.githubURL = url.absoluteString
                    UserDefaults.standard.set(model.githubURL, forKey: "githubURL")
                    model.editingRepository = false
                }.keyboardShortcut(.defaultAction).disabled(Self.validURL(value) == nil)
            }
        }.padding(20).frame(width: 340).onAppear { value = model.githubURL }
    }
}

@MainActor
final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = BrowserModel()
    var statusItem: NSStatusItem!
    let panel = MenuBarPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 430),
                        styleMask: [.borderless], backing: .buffered, defer: false)
    var previewWindow: NSWindow?
    var outsideClickMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "BroClean")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.toolTip = "BroClean — browser instances"
        panel.title = "BroClean"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        model.dismissPanel = { [weak self] in self?.hidePanel() }
        panel.contentViewController = NSHostingController(rootView: BrowserPanel(model: model))
        panel.hasShadow = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true
        if let view = panel.contentView { panel.setContentSize(view.fittingSize) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(waking), name: NSWorkspace.didWakeNotification, object: nil)
        model.start()
        if model.demo && CommandLine.arguments.contains("--preview-window") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "BroClean — Demo preview"
            window.contentViewController = NSHostingController(rootView: BrowserPanel(model: model))
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            NSApp.activate(ignoringOtherApps: true)
        } else if CommandLine.arguments.contains("--show") || model.demo { toggle() }

    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !panel.isVisible { toggle() }
        return true
    }
    @objc func toggle() {
        if panel.isVisible { hidePanel() }
        else if let button = statusItem.button, let buttonWindow = button.window {
            model.visible = true
            let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
            let x = max(screen.minX + 8, min(anchor.maxX - panel.frame.width, screen.maxX - panel.frame.width - 8))
            let y = max(screen.minY + 8, min(anchor.minY - panel.frame.height - 6, screen.maxY - panel.frame.height - 6))
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            if outsideClickMonitor == nil {
                outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.model.pending == nil, !self.model.busy, !self.model.editingRepository else { return }
                        self.hidePanel()
                    }
                }
            }
            Task { await model.refresh() }
        }
    }
    func hidePanel() {
        panel.orderOut(nil)
        model.visible = false
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
    @objc func sleeping() { model.sleeping = true }
    @objc func waking() { model.sleeping = false; Task { await model.refresh() } }
}
@main
struct BroCleanMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
