import Foundation
#if canImport(DevPetCore)
import DevPetCore
#endif
import Darwin

protocol UsageProvider: Sendable { func fetch() async -> UsageSnapshot }
struct ClaudeProvider: UsageProvider {
    static var bridgeURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/DevPet/claude-usage.json") }
    func fetch() async -> UsageSnapshot {
        await Task.detached(priority: .utility) {
            do {
                guard FileManager.default.fileExists(atPath: Self.bridgeURL.path) else { throw UsageError.missingBridge }
                let size = try Self.bridgeURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size < 65536 else { throw UsageError.invalidData }
                return try UsageParser.claude(Data(contentsOf: Self.bridgeURL))
            } catch { return UsageSnapshot(service: .claude, connection: .unavailable, diagnostic: error.localizedDescription) }
        }.value
    }
}
struct CodexProvider: UsageProvider {
    var executable: String
    static func locate(custom: String) -> String? {
        if !custom.isEmpty { return FileManager.default.isExecutableFile(atPath: custom) ? custom : nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex"]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    func fetch() async -> UsageSnapshot {
        await Task.detached(priority: .utility) {
            do { return try Self.read(executable: executable) }
            catch { return UsageSnapshot(service: .codex, connection: .failed, diagnostic: error.localizedDescription) }
        }.value
    }
    static func read(executable: String) throws -> UsageSnapshot {
        guard let path = locate(custom: executable) else { throw UsageError.missingCLI }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"]
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice // No credentials or unfiltered diagnostics are logged.
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        signal(SIGPIPE, SIG_IGN)
        try process.run()
        let deadline = DispatchWorkItem {
            if process.isRunning { process.terminate() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: deadline)
        defer {
            deadline.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
            try? output.fileHandleForReading.close()
        }
        func send(_ value: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: value); data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "devpet", "title": "DevPet", "version": "1.6.2"]]])
        var buffer = Data(), total = 0
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            // POSIX read returns available bytes immediately. Foundation read(upToCount:)
            // can wait for its entire requested size on a persistent JSON-lines pipe.
            let count = bytes.withUnsafeMutableBytes { Darwin.read(output.fileHandleForReading.fileDescriptor, $0.baseAddress, $0.count) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { break }
            let chunk = Data(bytes.prefix(count))
            total += chunk.count
            guard total < 2_000_000 else { throw UsageError.protocolFailure }
            buffer.append(chunk)
            while let end = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<end]); buffer.removeSubrange(...end)
                guard let response = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let id = response["id"] as? Int else { continue }
                if id == 1 {
                    guard response["error"] == nil else { throw UsageError.protocolFailure }
                    try send(["method": "initialized", "params": [:]])
                    try send(["id": 2, "method": "account/rateLimits/read"])
                } else if id == 2 {
                    guard response["error"] == nil else { throw UsageError.authentication }
                    return try UsageParser.codex(line, now: Date())
                }
            }
        }
        throw UsageError.timeout
    }
}
struct DemoProvider: UsageProvider {
    var service: Service
    var remaining: Double
    func fetch() async -> UsageSnapshot {
        let now = Date()
        let five = try! QuotaWindow(kind: .fiveHour, used: 100 - remaining, resetsAt: now.addingTimeInterval(9720))
        let weekly = try! QuotaWindow(kind: .weekly, used: service == .claude ? 79 : 61, resetsAt: now.addingTimeInterval(43200))
        return UsageSnapshot(service: service, windows: [five, weekly], refreshedAt: now, connection: .connected, diagnostic: "DEMO · Simulated data, not your account")
    }
}
