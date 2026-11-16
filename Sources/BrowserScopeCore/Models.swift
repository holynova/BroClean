import Foundation

public struct ProcessIdentity: Hashable, Codable, Sendable {
    public let pid: Int32
    public let startMicroseconds: UInt64
    public init(pid: Int32, startMicroseconds: UInt64) {
        self.pid = pid; self.startMicroseconds = startMicroseconds
    }
}

public struct ProcessRecord: Sendable, Equatable {
    public let identity: ProcessIdentity
    public let parentPID: Int32
    public let uid: UInt32
    public let path: String
    public let name: String
    // Ephemeral argv only. Never Codable, logged, or persisted.
    public var launchPath: String?
    public var arguments: [String]?
    public let residentBytes: UInt64?
    public init(pid: Int32, start: UInt64, parentPID: Int32, uid: UInt32, path: String,
                name: String = "", arguments: [String]? = nil, residentBytes: UInt64? = nil, launchPath: String? = nil) {
        identity = .init(pid: pid, startMicroseconds: start)
        self.parentPID = parentPID; self.uid = uid; self.path = path; self.name = name
        self.launchPath = launchPath
        self.arguments = arguments; self.residentBytes = residentBytes
    }
}

public enum BrowserFamily: String, Codable, Sendable {
    case chrome = "Chrome", chromium = "Chromium", chromeTesting = "Chrome for Testing"
    case edge = "Edge", safari = "Safari", firefox = "Firefox"
}
public enum BrowserMode: String, Codable, Sendable { case headless = "Headless", headed = "Headed", unknown = "Unknown mode" }
public enum ProfileKind: String, Codable, Sendable { case temporary = "Temporary", standard = "Standard", custom = "Custom", unknown = "Unknown" }
public struct SourceAttribution: Codable, Sendable, Equatable {
    public var software: String?
    public var framework: String?
    public var evidence: [String]
    public var launcherPID: Int32?
    public var launcherName: String?
    public var sharedLauncher = false
    public var displayName: String { software ?? framework ?? "Unknown source" }
    public var inferred: Bool { software != nil || framework != nil }
    public init(software: String? = nil, framework: String? = nil, evidence: [String] = [],
                launcherPID: Int32? = nil, launcherName: String? = nil) {
        self.software = software; self.framework = framework; self.evidence = evidence
        self.launcherPID = launcherPID; self.launcherName = launcherName
    }
}
public struct MemoryReading: Codable, Sendable, Equatable {
    public let bytes: UInt64?
    public let partial: Bool
    public let measuredProcesses: Int
    public let totalProcesses: Int
    public init(bytes: UInt64?, partial: Bool, measuredProcesses: Int, totalProcesses: Int) {
        self.bytes = bytes; self.partial = partial
        self.measuredProcesses = measuredProcesses; self.totalProcesses = totalProcesses
    }
    public var formatted: String {
        guard let bytes else { return "—" }
        if bytes >= 1_000_000_000 { return String(format: "%.1f GB", Double(bytes) / 1_000_000_000) }
        return "\(Int((Double(bytes) / 1_000_000).rounded())) MB"
    }
}
public struct PageReading: Codable, Sendable, Equatable {
    public let count: Int?
    public let reason: String?
    public let sampledAt: Date
    public init(count: Int? = nil, reason: String? = nil, sampledAt: Date = Date()) {
        self.count = count; self.reason = reason; self.sampledAt = sampledAt
    }
}

public struct BrowserInstance: Identifiable, Sendable, Equatable {
    public var id: ProcessIdentity { root.identity }
    public let root: ProcessRecord
    public let family: BrowserFamily
    public let mode: BrowserMode
    public let automated: Bool
    public let members: [ProcessRecord]
    public var source: SourceAttribution
    public let profileKind: ProfileKind
    // Sensitive path used for endpoint discovery/restart correlation, not exported.
    public let profilePath: String?
    public let memory: MemoryReading
    public let debugPort: Int?
    public let debuggingPipe: Bool
    public let protectedReason: String?
    public var likelyPersonalBrowser: Bool {
        mode == .headed && !automated && profileKind == .standard && debugPort == nil && !debuggingPipe && source.software == nil && source.framework == nil
    }
    public var displayTitle: String { likelyPersonalBrowser ? family.rawValue : source.displayName }
    public var usageLabel: String? { likelyPersonalBrowser ? "Personal browser" : nil }
    public var possiblyOrphaned: Bool { root.parentPID == 1 && automated }
    public var age: TimeInterval { max(0, Date().timeIntervalSince1970 - Double(id.startMicroseconds) / 1_000_000) }
    public var shortAge: String {
        let minutes = Int(age / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    public var bulkExclusion: String? { bulkExclusion(for: .headless) }
    public func bulkExclusion(for scope: BulkCloseScope) -> String? {
        if let protectedReason { return protectedReason }
        switch scope {
        case .headless: if mode != .headless { return "Not confirmed headless" }
        case .automated: if !automated { return "No automation evidence" }
        }
        if profileKind != .temporary { return "\(profileKind.rawValue) profile — review individually" }
        return nil
    }

}

public struct ProcessSnapshot: Sendable {
    public let records: [ProcessRecord]
    public let sampledAt: Date
    public init(records: [ProcessRecord], sampledAt: Date = Date()) { self.records = records; self.sampledAt = sampledAt }
}

public enum CloseStatus: String, Codable, Sendable { case closed = "Closed", stillRunning = "Still running", partial = "Partially closed", refused = "Refused", restarted = "Possibly restarted" }
public struct CloseResult: Codable, Sendable {
    public let identity: ProcessIdentity
    public let status: CloseStatus
    public let message: String
    public let remainingPIDs: [Int32]
    public init(identity: ProcessIdentity, status: CloseStatus, message: String, remainingPIDs: [Int32] = []) {
        self.identity = identity; self.status = status; self.message = message; self.remainingPIDs = remainingPIDs
    }
}
