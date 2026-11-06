import Foundation

public actor BrewCommandRunner {
    public static let shared = BrewCommandRunner()

    public var brewExecutablePath: String {
        Self.detectBrewExecutablePath() ?? "/opt/homebrew/bin/brew"
    }

    public var isBrewInstalled: Bool {
        Self.detectBrewExecutablePath() != nil
    }

    public static func detectBrewExecutablePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var activeProcess: Process?

    private init() {}

    private func setActiveProcess(_ process: Process?) {
        self.activeProcess = process
    }

    /// Terminates the currently running streaming `brew` process along with all descendant `ruby`/`curl` child processes.
    public func terminateActiveProcess() {
        guard let proc = activeProcess, proc.isRunning else { return }
        let rootPID = proc.processIdentifier
        Self.terminateProcessTree(rootPID: rootPID)
        proc.terminate()
    }

    private static func childPIDs(of parentPID: pid_t) -> [pid_t] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-P", "\(parentPID)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text
                .split(whereSeparator: \.isNewline)
                .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
        } catch {
            return []
        }
    }

    private static func terminateProcessTree(rootPID: pid_t) {
        let children = childPIDs(of: rootPID)
        for child in children {
            terminateProcessTree(rootPID: child)
            kill(child, SIGTERM)
        }
    }

    public static func logFileURL() throws -> URL {
        let fm = FileManager.default
        let libraryDir = try fm.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let logDir = libraryDir.appendingPathComponent("Logs/BrewGUI", isDirectory: true)
        if !fm.fileExists(atPath: logDir.path) {
            try fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        }
        return logDir.appendingPathComponent("brewgui.log")
    }

    public static func appendToDiskLog(_ text: String) {
        guard let url = try? logFileURL(),
              let data = text.data(using: .utf8) else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: data)
        } else if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }

    /// Truncates `brewgui.log` if it exceeds `maxBytes` (default 2 MB), keeping the last `keepLines` lines so disk logs stay compact.
    public static func rotateLogIfNeeded(maxBytes: UInt64 = 2 * 1024 * 1024, keepLines: Int = 2000) {
        guard let url = try? logFileURL(),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? UInt64,
              fileSize > maxBytes,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        let allLines = content.components(separatedBy: .newlines)
        let suffixLines = allLines.suffix(keepLines)
        let header = "=== [Log Trimmed: kept last \(suffixLines.count) lines from \(fileSize / 1024) KB] ===\n"
        let newContent = header + suffixLines.joined(separator: "\n")
        try? newContent.write(to: url, atomically: true, encoding: .utf8)
    }

    public func ensureAskpassScript() throws -> String {
        let appSupport = try Self.appSupportDirectory()
        let scriptURL = appSupport.appendingPathComponent("brewgui-askpass.sh")
        let scriptContent = """
        #!/bin/sh
        /usr/bin/osascript -e 'Tell application "System Events" to display dialog "BrewGUI 需要管理员权限以完成 Homebrew 软件包操作，请输入您的登录密码：" default answer "" with hidden answer with title "BrewGUI 权限请求" buttons {"取消", "好"} default button "好"' -e 'text returned of result' 2>/dev/null
        """
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL.path
    }

    public static func appSupportDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("BrewGUI", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Run a read-only brew command and capture stdout/stderr
    public func runCapture(arguments: [String], allowAutoUpdate: Bool = false) async throws -> (stdout: Data, stderr: String, exitCode: Int32) {
        let brewPath = self.brewExecutablePath
        let askpassPath = try? ensureAskpassScript()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = arguments

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["HOMEBREW_NO_COLOR"] = "1"
                if !allowAutoUpdate {
                    env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                }
                if let askpassPath {
                    env["SUDO_ASKPASS"] = askpassPath
                }
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (outData, errStr, process.terminationStatus))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Run a mutating brew command with live streaming output lines
    public func runStreaming(
        arguments: [String],
        allowAutoUpdate: Bool = false,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        let brewPath = self.brewExecutablePath
        let askpassPath = try? ensureAskpassScript()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = arguments

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["HOMEBREW_NO_COLOR"] = "1"
                if !allowAutoUpdate {
                    env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                }
                if let askpassPath {
                    env["SUDO_ASKPASS"] = askpassPath
                }
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        onOutput(text)
                    }
                }

                process.terminationHandler = { [weak self = self] proc in
                    Task {
                        await self?.setActiveProcess(nil)
                    }
                    handle.readabilityHandler = nil
                    let remaining = handle.readDataToEndOfFile()
                    if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                        onOutput(text)
                    }
                    continuation.resume(returning: proc.terminationStatus)
                }

                do {
                    try process.run()
                    Task {
                        await self.setActiveProcess(process)
                    }
                } catch {
                    handle.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
