import Testing
import BrowserScopeCore

struct GroupingTests {
    func instances() -> [BrowserInstance] {
        let path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        return BrowserResolver().resolve(.init(records: [
            .init(pid: 10, start: 10, parentPID: 1, uid: 501, path: path, arguments: ["--headless", "--user-data-dir=/tmp/playwright_one"]),
            .init(pid: 11, start: 11, parentPID: 1, uid: 501, path: path, arguments: ["--enable-automation", "--user-data-dir=/tmp/playwright_two"]),
            .init(pid: 12, start: 12, parentPID: 1, uid: 501, path: path, arguments: []),
            .init(pid: 13, start: 13, parentPID: 1, uid: 501, path: path, arguments: nil),
            .init(pid: 14, start: 14, parentPID: 1, uid: 501, path: path, arguments: ["--enable-automation"])
        ]), currentPID: 999, uid: 501)
    }
    @Test func groupsPartitionInstancesWithoutLosingUnknownSources() {
        let all = instances()
        let grouped = BrowserGroup.allCases.flatMap { group in all.filter(group.contains) }
        #expect(grouped.count == all.count)
        #expect(Set(grouped.map(\.id)).count == all.count)
        #expect(all.filter(BrowserGroup.other.contains).map(\.id.pid) == [13])
    }
    @Test func automatedGroupKeepsProtectionAndProfilePolicy() {
        let all = instances()
        let plan = GroupClosePlan(visible: all, group: .automated, protected: [all.first { $0.id.pid == 10 }!.id])
        #expect(plan.targets.map(\.id.pid) == [11])
        #expect(plan.skipped.count == 2)
        #expect(plan.scope == .automated)
    }
    @Test func visibleFilterCannotCloseHiddenGroupMembers() {
        let visible = instances().filter { $0.mode == .headless }
        let plan = GroupClosePlan(visible: visible, group: .automated, protected: [])
        #expect(plan.targets.map(\.id.pid) == [10])
    }
    @Test func personalGroupRequiresExplicitIndividualScopeAndSkipsProtected() {
        let all = instances()
        let personal = all.first { $0.id.pid == 12 }!
        let plan = GroupClosePlan(visible: all, group: .personal, protected: [])
        #expect(plan.targets.map(\.id.pid) == [12])
        #expect(plan.scope == nil)
        let protected = GroupClosePlan(visible: all, group: .personal, protected: [personal.id])
        #expect(protected.targets.isEmpty)
        #expect(protected.skipped.count == 1)
    }
}
