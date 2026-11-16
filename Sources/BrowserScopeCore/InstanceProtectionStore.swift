import Foundation
import Darwin

/// Shared by the menu-bar app and CLI. Identity includes start time, never a bare PID.
public struct InstanceProtectionStore: Sendable {
    public let directory: URL
    public init(directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/BroClean")) {
        self.directory = directory
    }
    private var file: URL { directory.appendingPathComponent("protected-instances.json") }
    public func load() throws -> Set<ProcessIdentity> {
        do { return try JSONDecoder().decode(Set<ProcessIdentity>.self, from: Data(contentsOf: file)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
    }
    public func set(_ identity: ProcessIdentity, protected: Bool) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let descriptor = open(directory.appendingPathComponent("protection.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        defer { flock(descriptor, LOCK_UN) }
        var values = try load()
        if protected { values.insert(identity) } else { values.remove(identity) }
        try JSONEncoder().encode(values).write(to: file, options: [.atomic])
    }
    /// Fail closed if the protection file cannot be read.
    public func protectsBulk(_ identity: ProcessIdentity) -> Bool { (try? load().contains(identity)) ?? true }
}
