import Foundation
import Darwin

public enum SignalError: Error, LocalizedError, Sendable, Equatable {
    case identityChanged, protectedProcess, permissionDenied, failed(Int32)
    public var errorDescription: String? {
        switch self {
        case .identityChanged: "Process identity changed or already exited. Refresh and try again."
        case .protectedProcess: "Protected process. No termination request was sent."
        case .permissionDenied: "Permission denied. No termination request was sent."
        case .failed(let code): "System request failed (errno \(code))."
        }
    }
}

public struct SignalGateway: Sendable {
    public let read: @Sendable (Int32) -> ProcessRecord?
    public let send: @Sendable (Int32, Int32) -> Int32
    public let uid: UInt32
    public let protectedPIDs: Set<Int32>
    public init(uid: UInt32 = getuid(), currentPID: Int32 = getpid(),
                read: @escaping @Sendable (Int32) -> ProcessRecord? = { ProcessScanner().read(pid: $0) },
                send: @escaping @Sendable (Int32, Int32) -> Int32 = { pid, signal in kill(pid, signal) == 0 ? 0 : errno }) {
        self.uid = uid; self.read = read; self.send = send
        var protected: Set<Int32> = [0, 1, currentPID]
        var parent = read(currentPID)?.parentPID
        while let pid = parent, protected.insert(pid).inserted { parent = read(pid)?.parentPID }
        self.protectedPIDs = protected
    }
    public func validate(_ expected: ProcessRecord) throws -> ProcessRecord {
        guard expected.identity.pid > 1, !protectedPIDs.contains(expected.identity.pid) else { throw SignalError.protectedProcess }
        guard expected.uid == uid else { throw SignalError.permissionDenied }
        guard let current = read(expected.identity.pid), current.identity == expected.identity,
              current.path == expected.path else { throw SignalError.identityChanged }
        guard current.uid == uid else { throw SignalError.permissionDenied }
        return current
    }
    public func signal(_ expected: ProcessRecord, force: Bool) throws {
        _ = try validate(expected)
        let result = send(expected.identity.pid, force ? SIGKILL : SIGTERM)
        if result == EPERM { throw SignalError.permissionDenied }
        if result != 0 { throw SignalError.failed(result) }
    }
}

public struct TerminationCoordinator: Sendable {
    private let snapshot: @Sendable () -> ProcessSnapshot
    private let gateway: SignalGateway
    private let pause: @Sendable (Duration) async -> Void
    public init(scanner: ProcessScanner = .init()) {
        snapshot = { scanner.scan() }
        gateway = SignalGateway(read: { scanner.read(pid: $0) })
        pause = { @Sendable duration in
            do { try await Task.sleep(for: duration) } catch {}
        }
    }
    // Inject system observations for deterministic lifecycle tests; production uses libproc.
    public init(snapshot: @escaping @Sendable () -> ProcessSnapshot, gateway: SignalGateway,
                pause: @escaping @Sendable (Duration) async -> Void) {
        self.snapshot = snapshot; self.gateway = gateway; self.pause = pause
    }
    public func close(_ instance: BrowserInstance, force: Bool = false, bulk: Bool = false, bulkScope: BulkCloseScope = .headless,
                      graceful: (@Sendable (ProcessRecord) async -> Bool)? = nil) async -> CloseResult {
        if let reason = instance.protectedReason {
            return .init(identity: instance.id, status: .refused, message: reason)
        }
        if bulk, InstanceProtectionStore().protectsBulk(instance.id) {
            return .init(identity: instance.id, status: .refused, message: "Protected from bulk cleanup, or protection settings are unreadable.")
        }
        if bulk, let reason = instance.bulkExclusion(for: bulkScope) {
            return .init(identity: instance.id, status: .refused, message: reason)
        }
        // Re-resolve before dispatch: don't trust a cached mode/profile/descendant relationship.
        let fresh = BrowserResolver().resolve(snapshot(), uid: gateway.uid).first { $0.id == instance.id }
        guard let fresh, fresh.root.path == instance.root.path else {
            return .init(identity: instance.id, status: .refused, message: "Identity changed or instance already exited.")
        }
        if bulk, let reason = fresh.bulkExclusion(for: bulkScope) { return .init(identity: instance.id, status: .refused, message: reason) }
        do {
            _ = try gateway.validate(fresh.root)
            if force {
                // Root first; the frozen verified children cannot expand into unrelated work.
                try gateway.signal(fresh.root, force: true)
                for member in fresh.members where member.identity != fresh.id {
                    try? gateway.signal(member, force: true)
                }
            } else {
                let requested = await graceful?(fresh.root) ?? false
                if !requested { try gateway.signal(fresh.root, force: false) }
            }
        } catch {
            return .init(identity: instance.id, status: .refused, message: error.localizedDescription)
        }
        var remaining: [ProcessRecord] = []
        for _ in 0..<(force ? 14 : 20) {
            await pause(.milliseconds(150))
            remaining = fresh.members.filter { gateway.read($0.identity.pid)?.identity == $0.identity }
            if remaining.isEmpty { break }
        }
        if !remaining.isEmpty {
            let rootAlive = remaining.contains { $0.identity == fresh.id }
            return .init(identity: instance.id, status: rootAlive ? .stillRunning : .partial,
                         message: rootAlive ? "The browser has not exited. Review it before using Force quit." : "Browser exited; \(remaining.count) verified helper(s) remain.",
                         remainingPIDs: remaining.map { $0.identity.pid })
        }
        // Watch briefly for relaunch under the same unique temporary profile.
        await pause(.milliseconds(600))
        if fresh.profileKind == .temporary, let profile = fresh.profilePath {
            let new = BrowserResolver().resolve(snapshot(), uid: gateway.uid).first { $0.id != fresh.id && $0.profilePath == profile }
            if let new {
                return .init(identity: instance.id, status: .restarted,
                             message: "A new browser uses the same temporary profile (PID \(new.id.pid)). Check the launcher; no further request was sent.", remainingPIDs: [new.id.pid])
            }
        }
        return .init(identity: instance.id, status: .closed, message: "Browser and \(max(0, fresh.members.count - 1)) verified helper(s) exited.")
    }
}
