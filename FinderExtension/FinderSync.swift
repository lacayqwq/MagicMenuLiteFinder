import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    private struct HostRequest: Codable {
        let id: String
        let action: String
        let kind: String?
        let directory: String?
        let paths: [String]?
        let createdAt: Date
    }

    private enum HostAction: String {
        case newFile
        case openVSCode
        case openCodex
        case openCodexCLI
        case openITerm
    }

    private enum MenuContext: String {
        case items
        case container
        case sidebar
        case toolbar

        init(menuKind: FIMenuKind) {
            switch menuKind {
            case .contextualMenuForItems:
                self = .items
            case .contextualMenuForContainer:
                self = .container
            case .contextualMenuForSidebar:
                self = .sidebar
            case .toolbarItemMenu:
                self = .toolbar
            @unknown default:
                self = .container
            }
        }

        var prefersContainer: Bool {
            self != .items
        }
    }

    private enum NewFileKind: String, CaseIterable {
        case txt
        case markdown
        case python
        case shell
        case html
        case json
        case csv

        var menuTitle: String {
            switch self {
            case .txt: return "TXT"
            case .markdown: return "Markdown"
            case .python: return "Python"
            case .shell: return "Shell 脚本"
            case .html: return "HTML"
            case .json: return "JSON"
            case .csv: return "CSV"
            }
        }
    }

    private enum MenuItemID: String {
        case copyPath
        case copyName
        case openVSCode
        case openCodex
        case openCodexCLI
        case openITerm
        case newFile
    }

    private var currentMenuContext: MenuContext = .container

    override init() {
        super.init()

        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/", isDirectory: true)
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let context = MenuContext(menuKind: menuKind)
        currentMenuContext = context
        let menu = NSMenu(title: "MagicMenu")
        let configuration = MenuConfigurationStore.load()

        for item in configuration.menuItems where item.enabled {
            guard let id = MenuItemID(rawValue: item.id) else { continue }

            switch id {
            case .copyPath:
                let copyTitle = context.prefersContainer ? "复制当前目录路径" : "复制路径"
                let copyItem = NSMenuItem(title: copyTitle, action: #selector(copyPaths(_:)), keyEquivalent: "")
                copyItem.target = self
                menu.addItem(copyItem)

            case .copyName:
                let copyTitle = context.prefersContainer ? "复制当前目录名" : "复制文件名"
                let copyItem = NSMenuItem(title: copyTitle, action: #selector(copyNames(_:)), keyEquivalent: "")
                copyItem.target = self
                menu.addItem(copyItem)

            case .openVSCode:
                let codeItem = NSMenuItem(title: "用 VS Code 打开", action: #selector(openWithVSCode), keyEquivalent: "")
                codeItem.target = self
                menu.addItem(codeItem)

            case .openCodex:
                let codexItem = NSMenuItem(title: "用 Codex 打开", action: #selector(openWithCodex), keyEquivalent: "")
                codexItem.target = self
                menu.addItem(codexItem)

            case .openCodexCLI:
                let codexCLIItem = NSMenuItem(title: "用 Codex CLI 打开", action: #selector(openWithCodexCLI), keyEquivalent: "")
                codexCLIItem.target = self
                menu.addItem(codexCLIItem)

            case .openITerm:
                let iTermItem = NSMenuItem(title: "用 iTerm2 打开", action: #selector(openWithITerm2), keyEquivalent: "")
                iTermItem.target = self
                menu.addItem(iTermItem)

            case .newFile:
                let enabledKinds = configuration.newFileItems
                    .filter(\.enabled)
                    .compactMap { NewFileKind(rawValue: $0.id) }

                guard !enabledKinds.isEmpty else { continue }

                let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
                let newFileMenu = NSMenu(title: "新建文件")
                enabledKinds.forEach { newFileMenu.addItem(newFileMenuItem(kind: $0)) }
                menu.setSubmenu(newFileMenu, for: newFileItem)
                menu.addItem(newFileItem)
            }
        }

        return menu.items.isEmpty ? nil : menu
    }

    private func newFileMenuItem(kind: NewFileKind) -> NSMenuItem {
        let item = NSMenuItem(title: kind.menuTitle, action: selector(for: kind), keyEquivalent: "")
        item.target = self
        return item
    }

    private func selector(for kind: NewFileKind) -> Selector {
        switch kind {
        case .txt: return #selector(createTextFile)
        case .markdown: return #selector(createMarkdownFile)
        case .python: return #selector(createPythonFile)
        case .shell: return #selector(createShellFile)
        case .html: return #selector(createHTMLFile)
        case .json: return #selector(createJSONFile)
        case .csv: return #selector(createCSVFile)
        }
    }

    @objc private func copyPaths(_ sender: NSMenuItem) {
        let urls = pathsToCopy(for: currentMenuContext)
        guard !urls.isEmpty else { return }

        let text = urls.map { $0.path }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func copyNames(_ sender: NSMenuItem) {
        let urls = pathsToCopy(for: currentMenuContext)
        guard !urls.isEmpty else { return }

        let text = urls
            .map { displayName(for: $0) }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func createTextFile() { createFile(kind: .txt) }
    @objc private func createMarkdownFile() { createFile(kind: .markdown) }
    @objc private func createPythonFile() { createFile(kind: .python) }
    @objc private func createShellFile() { createFile(kind: .shell) }
    @objc private func createHTMLFile() { createFile(kind: .html) }
    @objc private func createJSONFile() { createFile(kind: .json) }
    @objc private func createCSVFile() { createFile(kind: .csv) }

    @objc private func openWithVSCode() {
        let urls = pathsToOpenInVSCode(for: currentMenuContext)
        guard !urls.isEmpty else {
            logDebug("extension openWithVSCode missing paths")
            return
        }

        logDebug("extension openWithVSCode paths=\(urls.map(\.path).joined(separator: "|"))")
        requestHostAction(.openVSCode, paths: urls)
    }

    @objc private func openWithCodex() {
        let urls = pathsToOpenInCodex(for: currentMenuContext)
        guard !urls.isEmpty else {
            logDebug("extension openWithCodex missing paths")
            return
        }

        logDebug("extension openWithCodex paths=\(urls.map(\.path).joined(separator: "|"))")
        requestHostAction(.openCodex, paths: urls)
    }

    @objc private func openWithCodexCLI() {
        let urls = pathsToOpenInCodex(for: currentMenuContext)
        guard !urls.isEmpty else {
            logDebug("extension openWithCodexCLI missing paths")
            return
        }

        logDebug("extension openWithCodexCLI paths=\(urls.map(\.path).joined(separator: "|"))")
        requestHostAction(.openCodexCLI, paths: urls)
    }

    @objc private func openWithITerm2() {
        guard let directory = targetDirectory(for: currentMenuContext) else {
            logDebug("extension openWithITerm missing directory")
            return
        }

        logDebug("extension openWithITerm directory=\(directory.path)")
        requestHostAction(.openITerm, directory: directory)
    }

    private func createFile(kind: NewFileKind) {
        guard let directory = targetDirectory(for: currentMenuContext) else {
            logDebug("extension createFile missing directory kind=\(kind.rawValue)")
            return
        }

        logDebug("extension createFile kind=\(kind.rawValue) context=\(currentMenuContext.rawValue) directory=\(directory.path)")
        requestHostAction(.newFile, kind: kind, directory: directory)
    }

    private func pathsToCopy(for context: MenuContext) -> [URL] {
        if context.prefersContainer, let directory = targetDirectory(for: context) {
            return [directory]
        }

        return selectedOrTargetedURLs()
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func pathsToOpenInVSCode(for context: MenuContext) -> [URL] {
        if context.prefersContainer, let directory = targetDirectory(for: context) {
            return [directory]
        }

        let urls = selectedOrTargetedURLs()
        if !urls.isEmpty {
            return urls
        }

        if let directory = targetDirectory(for: context) {
            return [directory]
        }

        return []
    }

    private func pathsToOpenInCodex(for context: MenuContext) -> [URL] {
        if context.prefersContainer, let directory = targetDirectory(for: context) {
            return [directory]
        }

        let urls = selectedOrTargetedURLs()
        if !urls.isEmpty {
            return uniqueDirectories(for: urls)
        }

        if let directory = targetDirectory(for: context) {
            return [directory]
        }

        return []
    }

    private func uniqueDirectories(for urls: [URL]) -> [URL] {
        var directories: [URL] = []
        var seen = Set<String>()

        for url in urls {
            let directory = directoryURL(for: url)
            guard !seen.contains(directory.path) else { continue }
            directories.append(directory)
            seen.insert(directory.path)
        }

        return directories
    }

    private func selectedOrTargetedURLs() -> [URL] {
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []

        if !selected.isEmpty {
            return selected
        }

        if let targeted = controller.targetedURL() {
            return [targeted]
        }

        return []
    }

    private func targetDirectory(for context: MenuContext) -> URL? {
        let controller = FIFinderSyncController.default()

        if context.prefersContainer, let targeted = controller.targetedURL() {
            return directoryURL(for: targeted)
        }

        if let first = (controller.selectedItemURLs() ?? []).first {
            return directoryURL(for: first)
        }

        if let targeted = controller.targetedURL() {
            return directoryURL(for: targeted)
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    private func directoryURL(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func requestDirectoryURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return applicationSupport
            .appendingPathComponent("MagicMenuLiteFinder", isDirectory: true)
            .appendingPathComponent("Requests", isDirectory: true)
    }

    private func copyStatus(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func requestHostAction(_ action: HostAction, kind: NewFileKind? = nil, directory: URL? = nil, paths: [URL]? = nil) {
        do {
            try writeRequest(action: action, kind: kind, directory: directory, paths: paths)
        } catch {
            logDebug("extension write \(action.rawValue) request failed: \(error.localizedDescription)")
            copyStatus("MagicMenu：无法发送请求\n\(error.localizedDescription)")
            return
        }
        logDebug("extension wrote request action=\(action.rawValue)")

        DistributedNotificationCenter.default().postNotificationName(
            .magicMenuLiteNewFileRequest,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/MagicMenuLiteFinder.app", isDirectory: true))
    }

    private func writeRequest(action: HostAction, kind: NewFileKind? = nil, directory: URL? = nil, paths: [URL]? = nil) throws {
        let requestDirectory = try requestDirectoryURL()
        try FileManager.default.createDirectory(at: requestDirectory, withIntermediateDirectories: true)

        let request = HostRequest(
            id: UUID().uuidString,
            action: action.rawValue,
            kind: kind?.rawValue,
            directory: directory?.path,
            paths: paths?.map(\.path),
            createdAt: Date()
        )
        let data = try JSONEncoder().encode(request)
        let requestURL = requestDirectory.appendingPathComponent("\(request.id).json")
        try data.write(to: requestURL, options: .atomic)
        logDebug("extension request file=\(requestURL.path)")
    }

    private func logDebug(_ message: String) {
        let directory: URL
        do {
            directory = try requestDirectoryURL().deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let fileURL = directory.appendingPathComponent("debug.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"

        do {
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

private struct MenuConfigItem: Codable {
    let id: String
    var enabled: Bool
}

private struct MenuConfiguration: Codable {
    var version: Int
    var menuItems: [MenuConfigItem]
    var newFileItems: [MenuConfigItem]

    static var defaultConfiguration: MenuConfiguration {
        MenuConfiguration(
            version: 1,
            menuItems: ["copyPath", "copyName", "openVSCode", "openCodex", "openCodexCLI", "openITerm", "newFile"].map { MenuConfigItem(id: $0, enabled: true) },
            newFileItems: ["txt", "markdown", "python", "shell", "html", "json", "csv"].map { MenuConfigItem(id: $0, enabled: true) }
        )
    }

    func normalized() -> MenuConfiguration {
        MenuConfiguration(
            version: 1,
            menuItems: Self.normalizedItems(menuItems, defaultOrder: ["copyPath", "copyName", "openVSCode", "openCodex", "openCodexCLI", "openITerm", "newFile"]),
            newFileItems: Self.normalizedItems(newFileItems, defaultOrder: ["txt", "markdown", "python", "shell", "html", "json", "csv"])
        )
    }

    private static func normalizedItems(_ items: [MenuConfigItem], defaultOrder: [String]) -> [MenuConfigItem] {
        var result: [MenuConfigItem] = []
        var seen = Set<String>()

        for item in items where defaultOrder.contains(item.id) && !seen.contains(item.id) {
            result.append(item)
            seen.insert(item.id)
        }

        for id in defaultOrder where !seen.contains(id) {
            result.append(MenuConfigItem(id: id, enabled: true))
        }

        return result
    }
}

private enum MenuConfigurationStore {
    static func load() -> MenuConfiguration {
        guard
            let url = try? configurationURL(),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(MenuConfiguration.self, from: data)
        else {
            return .defaultConfiguration
        }

        return decoded.normalized()
    }

    private static func configurationURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return applicationSupport
            .appendingPathComponent("MagicMenuLiteFinder", isDirectory: true)
            .appendingPathComponent("MenuConfig.json")
    }
}

private extension Notification.Name {
    static let magicMenuLiteNewFileRequest = Notification.Name("dev.codex.MagicMenuLiteFinder.newFileRequest")
}
