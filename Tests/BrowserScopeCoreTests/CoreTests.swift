import Testing
import Foundation
import Darwin
@testable import BrowserScopeCore

struct CoreTests {
    let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
    func p(_ pid: Int32, parent: Int32 = 1, path: String? = nil, args: [String]? = [], memory: UInt64? = 100, start: UInt64 = 10, uid: UInt32 = 501) -> ProcessRecord {
        .init(pid: pid, start: start, parentPID: parent, uid: uid, path: path ?? chrome, arguments: args, residentBytes: memory)
    }
    func resolve(_ records: [ProcessRecord], current: Int32 = 999) -> [BrowserInstance] {
        BrowserResolver().resolve(.init(records: records), currentPID: current, uid: 501)
    }
    @Test func testAggregationExcludesNativeHostsAndIndependentRoots() {
        let result = resolve([p(10), p(11,parent:10,path:helper,memory:200), p(12,parent:11,path:helper,memory:300), p(13,parent:10,path:"/usr/bin/node"), p(14,parent:10)])
        #expect(result.count == 2)
        let first = result.first { $0.id.pid == 10 }!
        #expect(first.members.map(\.identity.pid) == [10,11,12])
        #expect(first.memory.bytes == 600)
    }
    @Test func testCodeSignCloneUsesKernelLaunchPathForGrouping() {
        let root = ProcessRecord(pid: 10, start: 10, parentPID: 1, uid: 501,
            path: "/private/var/folders/x/code_sign_clone/Google Chrome.app.bundle/Contents/MacOS/Google Chrome",
            arguments: [], residentBytes: 100, launchPath: chrome)
        let instance = resolve([root, p(11, parent: 10, path: helper, memory: 200)])[0]
        #expect(instance.members.count ==  2)
        #expect(instance.memory.bytes ==  300)
    }
    @Test func testSharedLauncherIsNotAggregated() {
        let result = resolve([p(2,path:"/Applications/Codex.app/Contents/MacOS/Codex"),p(3,parent:2,path:"/usr/local/bin/node",args:["node","playwright/cli.js"]), p(10,parent:3,args:["--headless","--user-data-dir=/tmp/playwright_one"]),p(20,parent:3,args:["--headless","--user-data-dir=/tmp/playwright_two"])])
        #expect(result.count == 2)
        for instance in result {
            #expect(instance.source.software == "Codex")
            #expect(instance.source.framework == "Playwright")
            #expect(instance.source.launcherPID == 3)
            #expect(instance.source.sharedLauncher)
            #expect(instance.members.count == 1)
        }
    }
    @Test func testBatchEligibilityPairedProfiles() {
        let result = resolve([p(10,args:["--headless","--user-data-dir=/tmp/playwright_safe"]), p(11,args:["--headless","--user-data-dir=/Users/me/Library/Application Support/Google/Chrome"]),p(12,args:["--headless","--user-data-dir=/tmp/my-real-profile"]),p(13,args:["--user-data-dir=/tmp/playwright_headed"]),p(14,args:nil),p(15,args:["--headless"])])
        #expect(result.filter { $0.bulkExclusion == nil }.map(\.id.pid) == [10])
        #expect(result.first { $0.id.pid == 14 }?.mode == .unknown)
    }
    @Test func testHeadlessDoesNotImplyAutomatedOrOrphanCleanup() {
        let instance = resolve([p(10,args:["--headless"])])[0]
        #expect(instance.mode == .headless)
        #expect(!(instance.automated))
        #expect(instance.bulkExclusion != nil)
    }
    @Test func testUnreadableMemoryAndSafariArePartial() {
        let result = resolve([p(10,memory:nil),p(11,parent:10,path:helper,memory:200),p(20,path:"/Applications/Safari.app/Contents/MacOS/Safari")])
        #expect(result[0].memory.bytes == 200)
        #expect(result[0].memory.partial)
        #expect(result[1].memory.partial)
    }
    @Test func testCurrentBrowserAncestorProtected() {
        let instance = resolve([p(10,args:["--headless","--user-data-dir=/tmp/playwright_test"]),p(999,parent:10,path:"/usr/bin/test")])[0]
        #expect(instance.protectedReason != nil)
        #expect(instance.bulkExclusion != nil)
    }
    @Test func testRendererWithSameExecutableIsNotRoot() {
        let result = resolve([p(10),p(11,parent:10,args:["--type=renderer"])])
        #expect(result.count == 1)
        #expect(result[0].members.count == 2)
    }
    @Test func testSourceURLIsNotFrameworkEvidence() {
        let instance = resolve([p(10,args:["https://playwright.dev"])])[0]
        #expect(instance.source.framework == nil)
    }
    @Test func testSignalRefusesPIDReusePathChangeAndOtherUser() {
        let expected = p(10)
        for changed in [p(10,start:11),p(10,path:"/bin/sleep"),p(10,uid:502)] {
            let gateway = SignalGateway(uid:501,currentPID:999,read:{ $0 == 10 ? changed : nil },send:{ _,_ in Issue.record("Must not signal stale identity"); return 0 })
            #expect(throws: (any Error).self) { try gateway.signal(expected,force:false) }
        }
    }
    @Test func testSignalProtectsAncestorsAndPropagatesDenial() {
        let records = [999:p(999,parent:10,path:"/bin/test"),10:p(10)]
        let protected = SignalGateway(uid:501,currentPID:999,read:{records[Int($0)]},send:{_,_ in Issue.record("Protected");return 0})
        #expect(throws: SignalError.protectedProcess) { try protected.signal(p(10),force:true) }
        let record = p(20)
        let denied = SignalGateway(uid:501,currentPID:999,read:{$0 == 20 ? record : nil},send:{_,signal in #expect(signal == SIGTERM);return EPERM})
        #expect(throws: SignalError.permissionDenied) { try denied.signal(record,force:false) }
    }
    @Test func testPagesDeduplicateAndExcludeWorkersFramesExtensions() throws {
        let data = Data("""
        [{"id":"a","type":"page","url":"about:blank"},{"id":"a","type":"page","url":"about:blank"},{"id":"b","type":"iframe","url":"https://example.com"},{"id":"c","type":"service_worker","url":"https://example.com"},{"id":"d","type":"page","url":"chrome-extension://abc"},{"id":"e","type":"page","url":"https://example.com"}]
        """.utf8)
        #expect(try PageProvider.countTargets(data) == 2)
        #expect(throws: (any Error).self) { try PageProvider.countTargets(Data("{}".utf8)) }
    }
    @Test func testActualProcessIdentityAndNormalSignal() throws {
        let child = Process(); child.executableURL = URL(fileURLWithPath:"/bin/sleep"); child.arguments = ["30"]
        try child.run()
        defer { if child.isRunning { child.terminate() }; child.waitUntilExit() }
        let record = try #require(ProcessScanner().read(pid: child.processIdentifier,arguments:true))
        #expect(record.arguments?.last == "30")
        #expect(record.uid == getuid())
        try SignalGateway().signal(record,force:false)
        child.waitUntilExit()
        #expect(!(child.isRunning))
    }
}

// A deterministic kernel boundary: no production process is touched by these lifecycle tests.
private final class LifecycleSystem: @unchecked Sendable {
    private let lock = NSLock()
    let initial: [ProcessRecord]
    let survivors: [ProcessRecord]
    let after: [ProcessRecord]
    private var signalled = false
    private var sent: [(Int32, Int32)] = []
    init(initial: [ProcessRecord], survivors: [ProcessRecord], after: [ProcessRecord] = []) {
        self.initial = initial; self.survivors = survivors; self.after = after
    }
    func snapshot() -> ProcessSnapshot { lock.withLock { .init(records: signalled ? after : initial) } }
    func read(_ pid: Int32) -> ProcessRecord? { lock.withLock { (signalled ? survivors : initial).first { $0.identity.pid == pid } } }
    func signal(_ pid: Int32, _ signal: Int32) -> Int32 { lock.withLock { sent.append((pid,signal)); signalled = true; return 0 } }
    var signals: [(Int32, Int32)] { lock.withLock { sent } }
    var coordinator: TerminationCoordinator {
        .init(snapshot: { self.snapshot() }, gateway: SignalGateway(uid:501,currentPID:999,read:{ self.read($0) },send:{ self.signal($0,$1) }), pause:{ _ in })
    }
}

extension CoreTests {
    @Test func testStillRunningDoesNotAutoEscalate() async {
        let root = p(10,args:["--headless","--user-data-dir=/tmp/playwright_one"])
        let system = LifecycleSystem(initial:[root],survivors:[root])
        let result = await system.coordinator.close(resolve([root])[0])
        #expect(result.status == .stillRunning)
        #expect(system.signals.count == 1)
        #expect(system.signals[0].1 == SIGTERM)
    }
    @Test func testPartialCloseReportsRemainingHelpers() async {
        let root = p(10)
        let child = p(11,parent:10,path:helper)
        let system = LifecycleSystem(initial:[root,child],survivors:[child])
        let result = await system.coordinator.close(resolve([root,child])[0])
        #expect(result.status == .partial)
        #expect(result.remainingPIDs == [11])
    }
    @Test func testRestartUnderSameProfileReportedWithoutSecondSignal() async {
        let root = p(10,args:["--headless","--user-data-dir=/tmp/playwright_one"])
        let replacement = p(20,args:root.arguments,start:20)
        let system = LifecycleSystem(initial:[root],survivors:[],after:[replacement])
        let result = await system.coordinator.close(resolve([root])[0],bulk:true)
        #expect(result.status == .restarted)
        #expect(result.remainingPIDs == [20])
        #expect(system.signals.count == 1)
    }
    @Test func testExplicitForceUsesKillAndRechecksChildIdentity() async {
        let root = p(10)
        let child = p(11,parent:10,path:helper)
        let reusedChild = p(11,parent:10,path:helper,start:99)
        let system = LifecycleSystem(initial:[root,child],survivors:[reusedChild])
        let result = await system.coordinator.close(resolve([root,child])[0],force:true)
        #expect(result.status == .closed)
        #expect(system.signals.count == 1)
        #expect(system.signals[0].1 == SIGKILL)
    }
    @Test func testBulkRevalidatesProfileAndRefusesChangedPolicy() async {
        let cached = p(10,args:["--headless","--user-data-dir=/tmp/playwright_one"])
        let current = p(10,args:["--headless"])
        let system = LifecycleSystem(initial:[current],survivors:[current])
        let result = await system.coordinator.close(resolve([cached])[0],bulk:true)
        #expect(result.status == .refused)
        #expect(system.signals.isEmpty)
    }
}

extension CoreTests {
    @Test func testNormalBrowserGetsPersonalLabelButAutomationStaysUnknown() {
        let normal = resolve([p(10)])[0]
        #expect(normal.likelyPersonalBrowser)
        #expect(normal.displayTitle == "Chrome")
        #expect(normal.usageLabel == "Personal browser")
        for args: [String]? in [nil, ["--headless"], ["--remote-debugging-port=9222"], ["--enable-automation"], ["--user-data-dir=/tmp/playwright_one"]] {
            let instance = resolve([p(10,args:args)])[0]
            #expect(!instance.likelyPersonalBrowser)
        }
    }
}

extension CoreTests {
    @Test func testNumericSortingKeepsUnknownLastInBothDirections() {
        let items = resolve([p(10,memory:100),p(20,memory:300),p(30,memory:nil)])
        let pages: [ProcessIdentity:PageReading] = [items[0].id:.init(count:0),items[1].id:.init(count:5)]
        for key in [BrowserSortKey.memory,.pages] {
            #expect(BrowserSorter.sorted(items,pages:pages,key:key,ascending:true).map(\.id.pid) == [10,20,30])
            #expect(BrowserSorter.sorted(items,pages:pages,key:key,ascending:false).map(\.id.pid) == [20,10,30])
        }
    }
    @Test func testNameTypeAndIdentitySorting() {
        let items = resolve([p(10,args:[],start:10),p(20,path:"/Applications/Safari.app/Contents/MacOS/Safari",args:[],start:20),p(30,args:["--headless"],start:30)])
        #expect(BrowserSorter.sorted(items,pages:[:],key:.name,ascending:true).map(\.id.pid) == [10,20,30])
        #expect(BrowserSorter.sorted(items,pages:[:],key:.name,ascending:false).map(\.id.pid) == [30,20,10])
        #expect(BrowserSorter.sorted(items,pages:[:],key:.type,ascending:true).first?.id.pid == 30)
        #expect(BrowserSorter.sorted(items,pages:[:],key:.type,ascending:false).last?.id.pid == 30)
        #expect(BrowserSorter.sorted(items,pages:[:],key:.pid,ascending:false).map(\.id.pid) == [30,20,10])
        #expect(BrowserSorter.sorted(items,pages:[:],key:.age,ascending:true).map(\.id.pid) == [30,20,10])
        #expect(BrowserSorter.sorted(items,pages:[:],key:.browser,ascending:false).first?.family == .safari)
    }
    @Test func testAutomatedBulkIncludesHeadedTemporaryButProtectsOrdinaryProfiles() {
        let items = resolve([p(10,args:["--user-data-dir=/tmp/playwright_headed"]),p(20,args:["--headless","--user-data-dir=/tmp/playwright_headless"]),p(30,args:["--enable-automation"]),p(40,args:[])])
        #expect(Set(items.filter { $0.bulkExclusion(for:.automated) == nil }.map(\.id.pid)) == [10,20])
        #expect(items.filter { $0.bulkExclusion == nil }.map(\.id.pid) == [20])
    }
    @Test func testAutomatedCloseScopeRevalidatedAtSignalBoundary() async {
        let root = p(10,args:["--user-data-dir=/tmp/playwright_headed"])
        let system = LifecycleSystem(initial:[root],survivors:[])
        let result = await system.coordinator.close(resolve([root])[0],bulk:true,bulkScope:.automated)
        #expect(result.status == .closed)
        #expect(system.signals.count == 1)
        let changed = p(10,args:[])
        let refused = LifecycleSystem(initial:[changed],survivors:[changed])
        #expect(await refused.coordinator.close(resolve([root])[0],bulk:true,bulkScope:.automated).status == .refused)
        #expect(refused.signals.isEmpty)
    }
}
