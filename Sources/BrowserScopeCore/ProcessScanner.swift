import Foundation
import CProcess
import Darwin

public struct ProcessScanner: Sendable {
    public init() {}
    public func read(pid: Int32, arguments: Bool = false) -> ProcessRecord? {
        var value = BSProcess()
        guard bs_read_process(pid, &value) == 1 else { return nil }
        let path = withUnsafePointer(to: &value.path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        let name = withUnsafePointer(to: &value.name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
        }
        let metadata = arguments ? readLaunchMetadata(pid: pid) : nil
        return ProcessRecord(pid: value.pid, start: value.start_microseconds, parentPID: value.ppid,
                             uid: value.uid, path: path, name: name,
                             arguments: metadata?.arguments,
                             residentBytes: value.memory_available == 1 ? value.resident_bytes : nil, launchPath: metadata?.path)
    }
    public func readArguments(pid: Int32) -> [String]? {
        readLaunchMetadata(pid: pid)?.arguments
    }
    private func readLaunchMetadata(pid: Int32) -> (arguments: [String], path: String)? {
        var length = 0
        var origin = [CChar](repeating: 0, count: 4096)
        guard let buffer = bs_copy_arguments(pid, &length, &origin, origin.count) else { return nil }
        defer { bs_wipe(buffer, length); free(buffer) }
        let data = UnsafeRawBufferPointer(start: buffer, count: length)
        let args = data.split(separator: 0, omittingEmptySubsequences: false).dropLast().map { String(decoding: $0, as: UTF8.self) }
        return (args, String(decoding: origin.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
    }
    public func scan(uid: UInt32 = getuid()) -> ProcessSnapshot {
        let count = max(256, Int(bs_list_pids(nil, 0)) + 256)
        var pids = [Int32](repeating: 0, count: count)
        let actual = pids.withUnsafeMutableBufferPointer { bs_list_pids($0.baseAddress, Int32(count)) }
        var records = pids.prefix(max(0, min(count, Int(actual)))).compactMap { read(pid: $0) }.filter { $0.uid == uid }
        let indices = Dictionary(uniqueKeysWithValues: records.enumerated().map { ($0.element.identity.pid, $0.offset) })
        var needsArgs = Set<Int32>()
        for process in records where BrowserResolver.family(path: process.path) != nil {
            var current: ProcessRecord? = process
            var visited = Set<Int32>()
            while let p = current, visited.insert(p.identity.pid).inserted, visited.count < 32 {
                needsArgs.insert(p.identity.pid)
                current = indices[p.parentPID].map { records[$0] }
            }
        }
        for pid in needsArgs {
            if let i = indices[pid], let metadata = readLaunchMetadata(pid: pid), read(pid: pid)?.identity == records[i].identity {
                records[i].arguments = metadata.arguments
                records[i].launchPath = metadata.path
            }
        }
        return ProcessSnapshot(records: records)
    }
    public func ownsListeningPort(pid: Int32, port: Int) -> Bool {
        guard (1...65535).contains(port) else { return false }
        return bs_owns_listening_port(pid, UInt16(port)) == 1
    }
}
