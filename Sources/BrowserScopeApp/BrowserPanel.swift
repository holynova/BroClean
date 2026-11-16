import AppKit
import SwiftUI
import ServiceManagement
import BrowserScopeCore

@MainActor private enum Theme {
    static let accent = Color(red: 0.196, green: 0.4, blue: 0.65)
    static let ink = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(calibratedRed: 0.66, green: 0.79, blue: 0.96, alpha: 1)
        : NSColor(calibratedRed: 0.14, green: 0.30, blue: 0.49, alpha: 1)
    })
    static let pale = accent.opacity(0.065)
    static let soft = accent.opacity(0.13)
}

struct BrowserPanel: View {
    @ObservedObject var model: BrowserModel
    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 6) {
                Text("Source").frame(maxWidth: .infinity, alignment: .leading)
                Text("Memory").frame(width: 62, alignment: .trailing)
                Text("Pages").frame(width: 32, alignment: .trailing)
                Color.clear.frame(width: 42, height: 1)
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 8)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.filtered.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: model.refreshing ? "arrow.clockwise" : "checkmark.circle").font(.system(size: 25)).foregroundStyle(Theme.ink)
                            Text(model.refreshing ? "Scanning browsers…" : "No browsers in this view").font(.system(size: 13, weight: .medium))
                            Text("Running browser instances appear here.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 45)
                    }
                    ForEach(BrowserGroup.allCases, id: \.self) { group in
                        let rows = model.filtered.filter(group.contains)
                        if !rows.isEmpty {
                            GroupHeading(model: model, group: group, rows: rows)
                            ForEach(rows) { instance in BrowserRow(model: model, instance: instance) }
                        }
                    }
                    feedback
                }
            }.frame(height: 370)
            if model.busy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(model.operationLabel).font(.system(size: 11)).lineLimit(1)
                    Spacer(minLength: 0)
                    Button(model.stopRequested ? "Stopping…" : "Stop remaining") { model.stopRequested = true }.font(.system(size: 10)).disabled(model.stopRequested)
                }.padding(12).background(Theme.soft)
            }
            footer
        }.frame(width: 400).background(Color(nsColor: .windowBackgroundColor)).tint(Theme.accent)
        .sheet(item: $model.pending) { action in CloseReview(model: model, action: action) }
        .sheet(isPresented: $model.editingRepository) { RepositorySettings(model: model) }
        .onExitCommand { if !model.busy && model.pending == nil { model.dismissPanel?() } }
    }
    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Text("BroClean").font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.ink)
                if model.demo { Text("Demo").font(.system(size: 10)).foregroundStyle(.secondary) }
                Spacer()
                if model.refreshing { ProgressView().controlSize(.mini).accessibilityLabel("Refreshing browsers") }
                Button { if model.demo { model.loadDemo() } else { Task { await model.refresh() } } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).foregroundStyle(Theme.ink).frame(width: 24, height: 24)
                    .help(model.demo ? "Reset demo" : "Refresh browsers").accessibilityLabel(model.demo ? "Reset demo" : "Refresh browsers")
                    .disabled(model.refreshing || model.busy).keyboardShortcut("r")
            }
            HStack {
                Text("\(model.instances.count) browsers · \(model.instances.filter { $0.mode == .headless }.count) headless")
                Spacer()
                Text(model.totalMemory).monospacedDigit().help("Estimated RSS sum. + means some memory is unavailable. Shared pages may be counted more than once.")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Picker("Browser filter", selection: $model.filter) { Text("All").tag("All"); Text("Automated").tag("Automated"); Text("Headless").tag("Headless") }
                    .pickerStyle(.segmented).labelsHidden().controlSize(.small)
                Menu {
                    Picker("Sort by", selection: $model.sortKey) { ForEach(BrowserSortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Divider()
                    Picker("Direction", selection: $model.sortAscending) { Text("Ascending").tag(true); Text("Descending").tag(false) }
                } label: { Image(systemName: "arrow.up.arrow.down") }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 22)
                    .help("Sort: \(model.sortKey.rawValue), \(model.sortAscending ? "ascending" : "descending")").accessibilityLabel("Sort browsers")
            }
        }.padding(14).background(Theme.pale)
    }
    @ViewBuilder private var feedback: some View {
        if let notice = model.notice {
            HStack(alignment: .top) {
                Text(notice).font(.system(size: 11)).textSelection(.enabled); Spacer(minLength: 5)
                Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss notice")
            }.padding(12).background(Theme.pale)
        }
        if !model.results.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("Last action").font(.system(size: 11, weight: .semibold)); Spacer(); Button("Dismiss") { model.results = [] }.buttonStyle(.plain).font(.system(size: 11)) }
                ForEach(Array(model.results.enumerated()), id: \.offset) { _, result in
                    Text("\(result.status.rawValue) · PID \(result.identity.pid)\n\(result.message)").font(.system(size: 11)).textSelection(.enabled)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.pale)
        }
    }
    private var footer: some View {
        HStack(spacing: 8) {
            Label("\(model.instances.filter { model.kept.contains($0.id) }.count) protected", systemImage: "lock")
                .font(.system(size: 11)).foregroundStyle(Theme.ink).help("Protected from group and bulk cleanup. An explicit individual close is still available.")
            Spacer(minLength: 0)
            Menu {
                Button("Close headless (\(model.eligible(.headless).count))…") { model.request(model.eligible(.headless), scope: .headless) }.disabled(model.eligible(.headless).isEmpty)
                Button("Close automated (\(model.eligible(.automated).count))…") { model.request(model.eligible(.automated), scope: .automated) }.disabled(model.eligible(.automated).isEmpty)
            } label: { Text("Review cleanup…").font(.system(size: 11, weight: .medium)).foregroundStyle(.white) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().padding(.horizontal, 9).padding(.vertical, 7)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6))
                .disabled(model.busy || (model.eligible(.headless).isEmpty && model.eligible(.automated).isEmpty))
            SettingsMenu(model: model).frame(width: 18)
        }.padding(12).background(Theme.pale)
    }
}

private struct GroupHeading: View {
    @ObservedObject var model: BrowserModel
    let group: BrowserGroup
    let rows: [BrowserInstance]
    var body: some View {
        let plan = GroupClosePlan(visible: rows, group: group, protected: model.kept)
        HStack(spacing: 6) {
            Text(group.rawValue).fontWeight(.semibold); Text(String(rows.count)).foregroundStyle(.secondary); Spacer()
            Button { model.requestGroup(group) } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .medium)).frame(width: 25, height: 25) }
                .buttonStyle(.plain).disabled(model.busy || plan.targets.isEmpty).accessibilityLabel("Close \(group.rawValue) group")
                .help(plan.targets.isEmpty ? "This group has no eligible browsers. Protected and unsafe bulk targets are skipped." : "Review and close \(plan.targets.count) browsers in this visible group")
        }.font(.system(size: 11)).foregroundStyle(Theme.ink).padding(.leading, 14).padding(.trailing, 11).padding(.vertical, 3).background(Theme.soft)
    }
}

private struct SourceMark: View {
    let instance: BrowserInstance
    private var source: String { instance.source.software ?? instance.source.framework ?? instance.family.rawValue }
    private static let templates: [String: NSImage] = {
        var result: [String: NSImage] = [:]
        let resources = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("BroClean_BrowserScopeApp.bundle")) } ?? Bundle.module
        for (source, file) in [("Claude", "claude"), ("ChatGPT", "chatgpt")] {
            if let url = resources.url(forResource: file, withExtension: "png"), let image = NSImage(contentsOf: url) { result[source] = image }
        }
        return result
    }()
    private var symbol: String {
        switch source { case "Codex", "Terminal": "terminal"; case "Playwright", "Puppeteer": "theatermasks"; case "Safari": "safari"; default: "globe" }
    }
    var body: some View {
        Group {
            if let image = Self.templates[source] { Image(nsImage: image).renderingMode(.template).resizable().scaledToFit().frame(width: 23, height: 23) }
            else { Image(systemName: symbol).resizable().scaledToFit().frame(width: 23, height: 23) }
        }.foregroundStyle(Theme.ink).frame(width: 29, height: 32).accessibilityHidden(true)
    }
}

private struct BrowserRow: View {
    @ObservedObject var model: BrowserModel
    let instance: BrowserInstance
    var expanded: Bool { model.selected == instance.id }
    private var secondary: String { instance.likelyPersonalBrowser ? "Personal browser" : "\(instance.family.rawValue) · \(instance.mode.rawValue)" }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button { model.selected = expanded ? nil : instance.id } label: {
                    HStack(spacing: 8) {
                        SourceMark(instance: instance)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Text(instance.displayTitle).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                if model.kept.contains(instance.id) { Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(Theme.ink).help("Protected from group cleanup") }
                            }
                            Text(secondary).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help(instance.source.inferred && !instance.likelyPersonalBrowser ? "Inferred source. Click for evidence and browser details." : "Show browser details")
                    .accessibilityLabel("\(instance.displayTitle)\(instance.source.inferred ? ", inferred source" : ""), \(model.kept.contains(instance.id) ? "protected, " : "")\(expanded ? "hide" : "show") details")
                Text(instance.memory.formatted + (instance.memory.partial && instance.memory.bytes != nil ? "+" : ""))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink).monospacedDigit().frame(width: 62, alignment: .trailing).help("Estimated process-tree RSS\(instance.memory.partial ? "; incomplete" : "")")
                Text(model.pages[instance.id]?.count.map(String.init) ?? "—").font(.system(size: 13)).monospacedDigit().frame(width: 32, alignment: .trailing).help(model.pages[instance.id]?.reason ?? "Top-level browser pages")
                Button { model.request([instance]) } label: { Image(systemName: "xmark").font(.system(size: 10)).frame(width: 22, height: 28) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).disabled(model.busy || instance.protectedReason != nil).accessibilityLabel("Close \(instance.displayTitle), PID \(instance.id.pid)").help("Close this browser…")
                Menu {
                    Button(expanded ? "Hide details" : "Show details") { model.selected = expanded ? nil : instance.id }
                    Button(model.kept.contains(instance.id) ? "Remove protection" : "Protect from group cleanup") { model.toggleProtection(instance) }.disabled(model.savingProtection)
                    Divider()
                    Button("Close browser…", role: .destructive) { model.request([instance]) }.disabled(model.busy || instance.protectedReason != nil)
                    Button("Force quit…", role: .destructive) { model.request([instance], force: true) }.disabled(model.busy || instance.protectedReason != nil)
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 14).accessibilityLabel("Actions for \(instance.displayTitle)")
            }.padding(.horizontal, 12).padding(.vertical, 12)
            if expanded { details }
            Divider().padding(.leading, 49)
        }.background(expanded || model.kept.contains(instance.id) ? Theme.pale : Color.clear)
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(instance.profileKind.rawValue) profile · \(instance.members.count) processes · Running \(instance.shortAge)").fontWeight(.medium)
            Text("Process PIDs: " + instance.members.map { String($0.identity.pid) }.joined(separator: ", ")).textSelection(.enabled)
            Text(instance.likelyPersonalBrowser ? "Likely personal use: standard profile without detected automation." : instance.source.inferred ? "Source inferred from process ancestry and launch arguments." : "No reliable source evidence is available.")
            if let launcher = instance.source.launcherPID { Text("Launcher PID \(launcher)\(instance.source.sharedLauncher ? " · Shared by multiple browsers" : "")") }
            if instance.possiblyOrphaned { Text("Parent is launchd. This alone does not mean the browser is abandoned.") }
            if let reason = model.kept.contains(instance.id) ? "Protected by you" : instance.bulkExclusion { Label(reason, systemImage: "lock") }
            if let reason = model.pages[instance.id]?.reason { Text("Pages: \(reason)") }
            ForEach(instance.source.evidence, id: \.self) { Text($0) }
        }.font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 14)
    }
}

private struct CloseReview: View {
    @ObservedObject var model: BrowserModel
    let action: CloseAction
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(action.title).font(.system(size: 17, weight: .semibold))
            Text(action.targets.contains { $0.likelyPersonalBrowser } ? "This includes your personal browser. Open windows and active work may be interrupted." : "Only the listed browsers will close. Active automation may be interrupted.").font(.system(size: 12)).foregroundStyle(.secondary)
            if action.force { Text("Force quit immediately stops the verified browser processes.").font(.system(size: 12)).foregroundStyle(.red) }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(action.targets) { instance in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(instance.displayTitle) · \(instance.family.rawValue)").font(.system(size: 12, weight: .medium))
                            Text("PID \(instance.id.pid) · \(instance.mode.rawValue)").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    if !action.skipped.isEmpty {
                        Divider(); Text("Skipped").font(.system(size: 11, weight: .semibold))
                        ForEach(action.skipped, id: \.self) { Text($0).font(.system(size: 11)).foregroundStyle(.secondary) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 260)
            HStack {
                Button("Cancel") { model.pending = nil }.keyboardShortcut(.cancelAction); Spacer()
                Button(action.force ? "Force quit" : "Close \(action.targets.count) \(action.targets.count == 1 ? "browser" : "browsers")", role: .destructive) {
                    model.pending = nil; model.execute(action)
                }.buttonStyle(.borderedProminent).tint(.red).disabled(action.targets.isEmpty)
            }.controlSize(.small)
        }.padding(22).frame(width: 360)
    }
}

private struct SettingsMenu: View {
    @ObservedObject var model: BrowserModel
    var body: some View {
        Menu {
            Text("BroClean \(model.version)")
            Button("GitHub") { if let url = RepositorySettings.validURL(model.githubURL) { NSWorkspace.shared.open(url) } else { model.editingRepository = true } }
            Button("Set GitHub repository…") { model.editingRepository = true }
            Divider()
            Button(SMAppService.mainApp.status == .enabled ? "Disable launch at login" : "Launch at login") { model.toggleLogin() }
            Button("About BroClean") { model.notice = "BroClean \(model.version) · Local process monitoring. Sources are inferred; memory is an RSS estimate; — means unavailable. Group cleanup skips protected browsers. Personal groups require explicit review." }
            if model.demo { Button("Reset demo") { model.loadDemo() }.disabled(model.busy) }
            Divider()
            Button("Quit BroClean") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: { Image(systemName: "gearshape") }.menuStyle(.borderlessButton).menuIndicator(.hidden).accessibilityLabel("Settings")
    }
}
