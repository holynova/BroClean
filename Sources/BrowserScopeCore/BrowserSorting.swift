import Foundation

public enum BrowserSortKey: String, CaseIterable, Sendable {
    case name = "Name", type = "Type", browser = "Browser", memory = "Memory", pages = "Pages", pid = "PID", age = "Age"
}

public enum BrowserSorter {
    public static func sorted(_ instances: [BrowserInstance], pages: [ProcessIdentity: PageReading],
                              key: BrowserSortKey, ascending: Bool) -> [BrowserInstance] {
        func compare<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
            a == b ? .orderedSame : a < b ? .orderedAscending : .orderedDescending
        }
        func modeRank(_ mode: BrowserMode) -> Int { mode == .headless ? 0 : mode == .headed ? 1 : 2 }
        return instances.sorted { a, b in
            let order: ComparisonResult
            switch key {
            case .name: order = a.displayTitle.localizedStandardCompare(b.displayTitle)
            case .browser: order = a.family.rawValue.localizedStandardCompare(b.family.rawValue)
            case .type: order = compare(modeRank(a.mode), modeRank(b.mode))
            case .pid: order = compare(a.id.pid, b.id.pid)
            case .age: order = compare(b.id.startMicroseconds, a.id.startMicroseconds)
            case .memory:
                // Missing values stay last in both directions; unknown is not zero.
                switch (a.memory.bytes, b.memory.bytes) {
                case (nil, nil): order = .orderedSame
                case (nil, _): return false
                case (_, nil): return true
                case let (left?, right?): order = compare(left, right)
                }
            case .pages:
                switch (pages[a.id]?.count, pages[b.id]?.count) {
                case (nil, nil): order = .orderedSame
                case (nil, _): return false
                case (_, nil): return true
                case let (left?, right?): order = compare(left, right)
                }
            }
            if order == .orderedSame {
                if a.id.startMicroseconds != b.id.startMicroseconds { return a.id.startMicroseconds < b.id.startMicroseconds }
                return a.id.pid < b.id.pid
            }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }
}

public enum BulkCloseScope: String, Sendable { case headless, automated }
