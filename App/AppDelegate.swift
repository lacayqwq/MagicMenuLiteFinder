import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct HostRequest: Codable {
        let action: String?
        let kind: String?
        let directory: String?
        let paths: [String]?
    }

    private enum HostAction: String {
        case newFile
        case openVSCode
        case openCodex
        case openCodexCLI
        case openITerm
    }

    private var handledURLLaunch = false
    private var preferencesWindowController: PreferencesWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        installMainMenu()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNewFileRequestNotification(_:)),
            name: .magicMenuLiteNewFileRequest,
            object: nil
        )

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if consumePendingRequests() {
            handledURLLaunch = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if !self.handledURLLaunch {
                self.showPreferencesWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if consumePendingRequests() {
            return false
        }

        if !flag {
            showPreferencesWindow()
        }

        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "MagicMenu Lite")
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            NSMenuItem(
                title: "退出 MagicMenu Lite",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "文件")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            NSMenuItem(
                title: "关闭窗口",
                action: #selector(NSWindow.performClose(_:)),
                keyEquivalent: "w"
            )
        )
    }

    private func showPreferencesWindow() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else {
            return
        }

        handledURLLaunch = true
        handleMagicMenuURL(url)
    }

    private func handleMagicMenuURL(_ url: URL) {
        guard url.scheme == "magicmenulitefinder", url.host == "new-file" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let query = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard
            let kindValue = query["kind"],
            let kind = NewFileKind(rawValue: kindValue),
            let directoryPath = query["directory"]
        else {
            copyStatus("MagicMenu Lite：新建文件参数无效")
            terminateSoon()
            return
        }

        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        var shouldTerminateAfterHandling = true
        do {
            try createAndReport(kind: kind, in: directory)
        } catch {
            shouldTerminateAfterHandling = false
            reportFailure("MagicMenu Lite：新建文件失败\n\(directory.path)\n\(error.localizedDescription)")
        }

        if shouldTerminateAfterHandling {
            terminateSoon()
        }
    }

    @objc private func handleNewFileRequestNotification(_ notification: Notification) {
        consumePendingRequests()
    }

    @discardableResult
    private func consumePendingRequests() -> Bool {
        let requestDirectory = extensionRequestDirectoryURL()
        guard
            let requestURLs = try? FileManager.default.contentsOfDirectory(
                at: requestDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return false
        }

        let jsonURLs = requestURLs
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !jsonURLs.isEmpty else {
            return false
        }

        var shouldTerminateAfterHandling = true

        for requestURL in jsonURLs {
            defer { try? FileManager.default.removeItem(at: requestURL) }

            do {
                logDebug("host handling request \(requestURL.path)")
                let data = try Data(contentsOf: requestURL)
                let request = try JSONDecoder().decode(HostRequest.self, from: data)
                try handle(request: request)
            } catch {
                shouldTerminateAfterHandling = false
                logDebug("host request failed: \(error.localizedDescription)")
                reportFailure("MagicMenu Lite：处理菜单请求失败\n\(error.localizedDescription)")
            }
        }

        if shouldTerminateAfterHandling {
            terminateSoon()
        }

        return true
    }

    private func handle(request: HostRequest) throws {
        guard let action = HostAction(rawValue: request.action ?? HostAction.newFile.rawValue) else {
            throw userFacingError("未知请求：\(request.action ?? "empty")")
        }

        switch action {
        case .newFile:
            guard
                let kindValue = request.kind,
                let kind = NewFileKind(rawValue: kindValue),
                let directoryPath = request.directory
            else {
                throw userFacingError("新建文件参数无效")
            }

            try createAndReport(kind: kind, in: URL(fileURLWithPath: directoryPath, isDirectory: true))

        case .openVSCode:
            let urls = (request.paths ?? []).map { URL(fileURLWithPath: $0) }
            guard !urls.isEmpty else {
                throw userFacingError("VS Code 打开路径为空")
            }

            try open(
                urls: urls,
                bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"],
                applicationNames: ["Visual Studio Code", "Visual Studio Code - Insiders"],
                appName: "VS Code"
            )
            logDebug("host opened VS Code paths=\(urls.map(\.path).joined(separator: "|"))")

        case .openCodex:
            let urls = (request.paths ?? []).map { URL(fileURLWithPath: $0) }
            guard !urls.isEmpty else {
                throw userFacingError("Codex 打开路径为空")
            }

            try openCodexWorkspaces(urls)
            logDebug("host opened Codex paths=\(urls.map(\.path).joined(separator: "|"))")

        case .openCodexCLI:
            let urls = (request.paths ?? []).map { URL(fileURLWithPath: $0, isDirectory: true) }
            guard !urls.isEmpty else {
                throw userFacingError("Codex CLI 打开路径为空")
            }

            try openCodexCLIWorkspaces(urls)
            logDebug("host opened Codex CLI paths=\(urls.map(\.path).joined(separator: "|"))")

        case .openITerm:
            guard let directoryPath = request.directory else {
                throw userFacingError("iTerm2 打开目录为空")
            }

            let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
            try open(
                urls: [directory],
                bundleIdentifiers: ["com.googlecode.iterm2"],
                applicationNames: ["iTerm", "iTerm2"],
                appName: "iTerm2"
            )
            logDebug("host opened iTerm2 directory=\(directory.path)")
        }
    }

    private func createAndReport(kind: NewFileKind, in directory: URL) throws {
        let fileURL = try createFile(kind: kind, in: directory)
        logDebug("host created \(fileURL.path)")
        revealInFinderAndStartRename(fileURL)
        copyStatus(fileURL.path)
    }

    private func revealInFinderAndStartRename(_ fileURL: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.startFinderRenameIfAllowed()
        }
    }

    private func startFinderRenameIfAllowed() {
        guard accessibilityPermissionIsGranted() else {
            let message = "MagicMenu Lite：需要辅助功能权限才能自动进入重命名状态。请在系统设置 > 隐私与安全性 > 辅助功能 中允许 MagicMenuLiteFinder。"
            logDebug(message)
            copyStatus(message)
            return
        }

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false)
        else {
            logDebug("host failed to create Return key events")
            return
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        logDebug("host posted Return key for Finder rename")
    }

    private func accessibilityPermissionIsGranted() -> Bool {
        let trusted = AXIsProcessTrusted()
        logDebug("host accessibility trusted=\(trusted)")
        return trusted
    }

    private func createFile(kind: NewFileKind, in directory: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw CocoaError(.fileWriteNoPermission)
        }

        let fileURL = uniqueFileURL(in: directory, preferredName: kind.fileName)
        guard FileManager.default.createFile(atPath: fileURL.path, contents: kind.template) else {
            throw CocoaError(.fileWriteUnknown)
        }

        if kind.isExecutable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
        }

        return fileURL
    }

    private func uniqueFileURL(in directory: URL, preferredName: String) -> URL {
        let fileManager = FileManager.default
        let baseURL = directory.appendingPathComponent(preferredName)

        if !fileManager.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        let name = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension

        for index in 2..<10_000 {
            let candidateName = ext.isEmpty ? "\(name) \(index)" : "\(name) \(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    private func copyStatus(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func reportFailure(_ text: String) {
        copyStatus(text)

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "MagicMenu Lite"
            alert.informativeText = text
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            self.terminateSoon()
        }
    }

    private func open(urls: [URL], bundleIdentifiers: [String], applicationNames: [String], appName: String) throws {
        let paths = urls.map(\.path)
        var errors: [String] = []

        for bundleIdentifier in bundleIdentifiers {
            do {
                try runOpen(arguments: ["-b", bundleIdentifier] + paths)
                return
            } catch {
                errors.append("\(bundleIdentifier): \(error.localizedDescription)")
            }
        }

        for applicationName in applicationNames {
            do {
                try runOpen(arguments: ["-a", applicationName] + paths)
                return
            } catch {
                errors.append("\(applicationName): \(error.localizedDescription)")
            }
        }

        throw userFacingError("无法打开 \(appName)。请确认已经安装。\n\(errors.joined(separator: "\n"))")
    }

    private func runOpen(arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = arguments

        let errorPipe = Pipe()
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw userFacingError(message?.isEmpty == false ? message! : "open 命令失败，退出码 \(task.terminationStatus)")
        }
    }

    private func openCodexWorkspaces(_ urls: [URL]) throws {
        for url in urls {
            try runCodexApp(path: url.path)
        }
    }

    private func openCodexCLIWorkspaces(_ urls: [URL]) throws {
        let codexExecutable = try codexExecutableURL()
        for url in urls {
            try runCodexCLIInITerm(directory: url, codexExecutable: codexExecutable)
        }
    }

    private func runCodexApp(path: String) throws {
        let codexExecutable = try codexExecutableURL()
        let task = Process()
        task.executableURL = codexExecutable
        task.arguments = ["app", path]
        task.environment = processEnvironmentWithHomebrewPath()

        let errorPipe = Pipe()
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw userFacingError(message?.isEmpty == false ? message! : "codex app 命令失败，退出码 \(task.terminationStatus)")
        }
    }

    private func runCodexCLIInITerm(directory: URL, codexExecutable: URL) throws {
        let command = [
            "export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH",
            "cd \(shellQuoted(directory.path))",
            shellQuoted(codexExecutable.path)
        ].joined(separator: " && ")

        let iTermApplications = iTermApplicationURLs()
        guard !iTermApplications.isEmpty else {
            throw userFacingError("无法找到 iTerm2。请确认 iTerm2 已安装在 /Applications。")
        }

        var errors: [String] = []
        for applicationURL in iTermApplications {
            let script = """
            tell application \(appleScriptStringLiteral(applicationURL.path))
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text \(appleScriptStringLiteral(command))
                end tell
            end tell
            """

            do {
                try runAppleScript(script, failureMessage: "\(applicationURL.lastPathComponent) AppleScript 执行失败")
                return
            } catch {
                errors.append("\(applicationURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        throw userFacingError("无法用 iTerm2 打开 Codex CLI。请确认已经安装 iTerm2。\n\(errors.joined(separator: "\n"))")
    }

    private func iTermApplicationURLs() -> [URL] {
        [
            "/Applications/iTerm.app",
            "/Applications/iTerm2.app"
        ]
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func runAppleScript(_ script: String, failureMessage: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.environment = processEnvironmentWithHomebrewPath()

        let errorPipe = Pipe()
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw userFacingError(message?.isEmpty == false ? "\(failureMessage)\n\(message!)" : failureMessage)
        }
    }

    private func codexExecutableURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        throw userFacingError("无法找到 Codex CLI。请确认 `codex` 已安装在 /opt/homebrew/bin 或 /usr/local/bin。")
    }

    private func shellQuoted(_ text: String) -> String {
        "'\(text.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptStringLiteral(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func processEnvironmentWithHomebrewPath() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            environment["PATH"] = "\(extraPath):\(existingPath)"
        } else {
            environment["PATH"] = extraPath
        }
        return environment
    }

    private func userFacingError(_ message: String) -> NSError {
        NSError(domain: "MagicMenuLiteFinder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func terminateSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if self.preferencesWindowController?.window?.isVisible == true {
                return
            }
            NSApp.terminate(nil)
        }
    }

    private func extensionRequestDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("dev.codex.MagicMenuLiteFinder.FinderExtension", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MagicMenuLiteFinder", isDirectory: true)
            .appendingPathComponent("Requests", isDirectory: true)
    }

    private func hostSupportDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MagicMenuLiteFinder", isDirectory: true)
    }

    private func logDebug(_ message: String) {
        let directory = hostSupportDirectoryURL()
        let fileURL = directory.appendingPathComponent("debug.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try Data(line.utf8).write(to: fileURL, options: .atomic)
            }
        } catch {
            // Logging must never break menu handling.
        }
    }
}

private extension Notification.Name {
    static let magicMenuLiteNewFileRequest = Notification.Name("dev.codex.MagicMenuLiteFinder.newFileRequest")
}

private enum NewFileKind: String {
    case txt
    case markdown
    case python
    case shell
    case html
    case json
    case csv

    var fileName: String {
        switch self {
        case .txt: return "Untitled.txt"
        case .markdown: return "Untitled.md"
        case .python: return "untitled.py"
        case .shell: return "untitled.sh"
        case .html: return "Untitled.html"
        case .json: return "Untitled.json"
        case .csv: return "Untitled.csv"
        }
    }

    var template: Data {
        let text: String
        switch self {
        case .txt, .csv:
            text = ""
        case .markdown:
            text = "# \n"
        case .python:
            text = "#!/usr/bin/env python3\n\n"
        case .shell:
            text = "#!/bin/zsh\nset -euo pipefail\n\n"
        case .html:
            text = """
            <!doctype html>
            <html lang="zh-CN">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Untitled</title>
            </head>
            <body>

            </body>
            </html>
            """
        case .json:
            text = "{\n  \n}\n"
        }
        return Data(text.utf8)
    }

    var isExecutable: Bool {
        self == .shell
    }
}
