import Foundation

public enum BrowserGroup: String, CaseIterable, Sendable {
    case automated = "Automated", personal = "Personal", other = "Other"
    public func contains(_ instance: BrowserInstance) -> Bool {
        switch self {
        case .automated: instance.automated
        case .personal: !instance.automated && instance.likelyPersonalBrowser
        case .other: !instance.automated && !instance.likelyPersonalBrowser
        }
    }
}

/// A user-reviewed group is frozen from the currently visible instances.
/// Automated groups keep the existing bulk profile policy. Personal/other
/// groups are an explicit list of individual closes, never automatic cleanup.
public struct GroupClosePlan: Sendable {
    public let targets: [BrowserInstance]
    public let skipped: [String]
    public let scope: BulkCloseScope?
    public init(visible: [BrowserInstance], group: BrowserGroup, protected: Set<ProcessIdentity>) {
        scope = group == .automated ? .automated : nil
        var accepted: [BrowserInstance] = []
        var excluded: [String] = []
        for instance in visible where group.contains(instance) {
            let reason = protected.contains(instance.id) ? "Protected by you"
                : instance.protectedReason ?? (group == .automated ? instance.bulkExclusion(for: .automated) : nil)
            if let reason { excluded.append("\(instance.displayTitle) · PID \(instance.id.pid): \(reason)") }
            else { accepted.append(instance) }
        }
        targets = accepted
        skipped = excluded
    }
}
