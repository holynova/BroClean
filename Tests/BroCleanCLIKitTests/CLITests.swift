import Testing
import Foundation
import BroCleanCLIKit
import BrowserScopeCore

struct CLITests {
    func instance(pid: Int32 = 123, args: [String] = ["--headless", "--user-data-dir=/tmp/playwright_cli"], start: UInt64 = 10) -> BrowserInstance {
        let root = ProcessRecord(pid: pid,start:start,parentPID:1,uid:501,path:"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",arguments:args)
        return BrowserResolver().resolve(.init(records:[root]),currentPID:999,uid:501)[0]
    }
    @Test func defaultListAndSortOptions() throws {
        #expect(try Options.parse([]).command == .list)
        let options = try Options.parse(["list","--automated","--sort","memory","--desc","--json"])
        #expect(options.scope == .automated)
        #expect(options.sort == .memory)
        #expect(!options.ascending)
        #expect(options.json)
    }
    @Test func invalidTargetsCannotBecomeBroadCleanup() {
        for args in [["close"],["close","--headles","--yes"],["close","0","--yes"],["close","123","--headless"],["close","--headless","--automated"],["close","--automated","--force"],["close","--headless","--exclude","123,bad"],["close","--start-time","10","--headless"],["list","--force"],["list","--sort","bad"],["list","--asc","--desc"],["inspect"],["protect","123","--automated"],["close","123","--json","--json"]] {
            #expect(throws:(any Error).self) { try Options.parse(args) }
        }
    }
    @Test func bulkPlanSeparatesProtectedExcludedAndUnsafeProfiles() throws {
        let a=instance(pid:10), b=instance(pid:20), c=instance(pid:30,args:["--headless"]), d=instance(pid:40)
        let options=try Options.parse(["close","--headless","--exclude","40","--dry-run"])
        let plan=try ClosePlan.make(instances:[a,b,c,d],options:options,protected:[b.id])
        #expect(plan.targets.map(\.id.pid) == [10])
        #expect(plan.skipped.map(\.pid) == [20,30,40])
    }
    @Test func singleCloseRequiresMatchingIdentityButCanReviewPersonalBrowser() throws {
        let browser=instance(args:[])
        let stale=try Options.parse(["close","123","--start-time","11","--yes"])
        #expect(throws:(any Error).self) { try ClosePlan.make(instances:[browser],options:stale,protected:[]) }
        let valid=try Options.parse(["close","123","--start-time","10","--dry-run"])
        #expect(try ClosePlan.make(instances:[browser],options:valid,protected:[browser.id]).targets.count == 1)
    }
    @Test func automatedScopeIncludesHeadedWithoutSelectingPersonalBrowser() throws {
        let automated=instance(pid:10,args:["--user-data-dir=/tmp/playwright_headed"])
        let personal=instance(pid:20,args:[])
        let options=try Options.parse(["close","--automated","--yes"])
        #expect(try ClosePlan.make(instances:[automated,personal],options:options,protected:[]).targets.map(\.id.pid) == [10])
    }
    @Test func sharedProtectionUsesIdentityAndPreservesOtherEntries() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let first=InstanceProtectionStore(directory:dir), second=InstanceProtectionStore(directory:dir)
        let a=ProcessIdentity(pid:123,startMicroseconds:10), b=ProcessIdentity(pid:456,startMicroseconds:20)
        try first.set(a,protected:true); try second.set(b,protected:true)
        #expect(try first.load() == [a,b])
        #expect(!first.protectsBulk(.init(pid:123,startMicroseconds:99)))
        try second.set(a,protected:false)
        #expect(try first.load() == [b])
        try Data("broken".utf8).write(to:dir.appendingPathComponent("protected-instances.json"))
        #expect(first.protectsBulk(a))
        #expect(throws:(any Error).self) { try first.set(a,protected:true) }
    }
}
