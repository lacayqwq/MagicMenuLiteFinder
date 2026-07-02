import Cocoa

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private enum Section: String {
        case menu
        case newFile
    }

    private let scrollView = NSScrollView()
    private let contentView = FlippedDocumentView()
    private let stackView = NSStackView()
    private let menuRowsStack = NSStackView()
    private let newFileRowsStack = NSStackView()
    private var configuration = MenuConfigurationStore.load()

    init() {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 760
        let windowHeight = min(640, max(460, visibleHeight - 120))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MagicMenu Lite"
        window.minSize = NSSize(width: 680, height: 420)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildInterface(in: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildInterface(in window: NSWindow) {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = rootView

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(scrollView)

        contentView.frame = NSRect(x: 0, y: 0, width: window.contentLayoutRect.width, height: window.contentLayoutRect.height)
        scrollView.documentView = contentView

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        stackView.addArrangedSubview(headerView())
        stackView.addArrangedSubview(cardView(
            title: "一级菜单",
            subtitle: "控制 Finder 右键菜单中直接出现的功能和顺序。",
            rowsStack: menuRowsStack
        ))
        stackView.addArrangedSubview(cardView(
            title: "新建文件",
            subtitle: "控制“新建文件”子菜单中出现的文件类型和顺序。",
            rowsStack: newFileRowsStack
        ))
        stackView.addArrangedSubview(footerView())

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
        ])

        rebuildRows()
    }

    func windowDidResize(_ notification: Notification) {
        updateDocumentSize()
    }

    private func updateDocumentSize() {
        guard scrollView.documentView === contentView else { return }

        let width = max(scrollView.contentView.bounds.width, 680)
        if contentView.frame.width != width {
            contentView.setFrameSize(NSSize(width: width, height: max(contentView.frame.height, 1)))
        }

        contentView.layoutSubtreeIfNeeded()
        let height = max(scrollView.contentView.bounds.height, stackView.fittingSize.height + 40)
        contentView.setFrameSize(NSSize(width: width, height: height))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func headerView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(named: "MagicMenuLiteFinder") ?? NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "MagicMenu Lite 设置")
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: "调整右键菜单的开关和顺序。修改会立即保存，使用时不需要打开这个窗口。")
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 54),
            iconView.heightAnchor.constraint(equalToConstant: 54),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])

        return container
    }

    private func cardView(title: String, subtitle: String, rowsStack: NSStackView) -> NSView {
        let card = RoundedPanelView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        return card
    }

    private func footerView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "恢复默认", target: self, action: #selector(resetDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let reloadButton = NSButton(title: "重新读取", target: self, action: #selector(reloadConfiguration))
        reloadButton.bezelStyle = .rounded
        reloadButton.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = NSTextField(labelWithString: "如果 Finder 菜单没有立刻变化，重新打开右键菜单即可。")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(resetButton)
        container.addSubview(reloadButton)
        container.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            resetButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            resetButton.topAnchor.constraint(equalTo: container.topAnchor),
            resetButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            reloadButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 8),
            reloadButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor)
        ])

        return container
    }

    private func rebuildRows() {
        rebuildRows(
            in: menuRowsStack,
            section: .menu,
            items: configuration.menuItems,
            titles: MenuCatalog.menuTitles,
            subtitles: MenuCatalog.menuSubtitles
        )
        rebuildRows(
            in: newFileRowsStack,
            section: .newFile,
            items: configuration.newFileItems,
            titles: MenuCatalog.newFileTitles,
            subtitles: MenuCatalog.newFileSubtitles
        )
    }

    private func rebuildRows(
        in stackView: NSStackView,
        section: Section,
        items: [MenuConfigItem],
        titles: [String: String],
        subtitles: [String: String]
    ) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, item) in items.enumerated() {
            stackView.addArrangedSubview(rowView(
                section: section,
                index: index,
                item: item,
                title: titles[item.id] ?? item.id,
                subtitle: subtitles[item.id] ?? ""
            ))

            if index < items.count - 1 {
                stackView.addArrangedSubview(separatorView())
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateDocumentSize()
        }
    }

    private func rowView(section: Section, index: Int, item: MenuConfigItem, title: String, subtitle: String) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = icon(for: item.id)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let toggle = NSSwitch()
        toggle.state = item.enabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleItem(_:))
        toggle.tag = index
        toggle.identifier = NSUserInterfaceItemIdentifier(section.rawValue)
        toggle.translatesAutoresizingMaskIntoConstraints = false

        let upButton = iconButton(symbol: "chevron.up", identifier: "\(section.rawValue)-up", tag: index, enabled: index > 0)
        let downButton = iconButton(symbol: "chevron.down", identifier: "\(section.rawValue)-down", tag: index, enabled: index < rowCount(for: section) - 1)

        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(subtitleLabel)
        row.addSubview(toggle)
        row.addSubview(upButton)
        row.addSubview(downButton)

        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            row.heightAnchor.constraint(equalToConstant: 52),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -18),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            downButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            downButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            upButton.trailingAnchor.constraint(equalTo: downButton.leadingAnchor, constant: -6),
            upButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            toggle.trailingAnchor.constraint(equalTo: upButton.leadingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func separatorView() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        return separator
    }

    private func iconButton(symbol: String, identifier: String, tag: Int, enabled: Bool) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.bezelStyle = .rounded
        button.isBordered = true
        button.target = self
        button.action = #selector(moveItem(_:))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.tag = tag
        button.isEnabled = enabled
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 26)
        ])
        return button
    }

    private func icon(for id: String) -> NSImage? {
        let symbolName: String
        switch id {
        case "copyPath": symbolName = "doc.on.doc"
        case "copyName": symbolName = "textformat"
        case "openVSCode": symbolName = "chevron.left.forwardslash.chevron.right"
        case "openCodex": symbolName = "sparkles"
        case "openCodexCLI": symbolName = "terminal.fill"
        case "openITerm": symbolName = "terminal"
        case "newFile": symbolName = "doc.badge.plus"
        case "txt": symbolName = "doc.text"
        case "markdown": symbolName = "text.alignleft"
        case "python": symbolName = "curlybraces"
        case "shell": symbolName = "terminal"
        case "html": symbolName = "globe"
        case "json": symbolName = "curlybraces.square"
        case "csv": symbolName = "tablecells"
        default: symbolName = "circle"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    @objc private func toggleItem(_ sender: NSSwitch) {
        let section = Section(rawValue: sender.identifier?.rawValue ?? "")
        switch section {
        case .menu:
            guard configuration.menuItems.indices.contains(sender.tag) else { return }
            configuration.menuItems[sender.tag].enabled = sender.state == .on
        case .newFile:
            guard configuration.newFileItems.indices.contains(sender.tag) else { return }
            configuration.newFileItems[sender.tag].enabled = sender.state == .on
        case nil:
            return
        }

        saveAndRebuild()
    }

    @objc private func moveItem(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else { return }
        let isUp = identifier.hasSuffix("-up")
        let section: Section = identifier.hasPrefix(Section.menu.rawValue) ? .menu : .newFile
        let offset = isUp ? -1 : 1

        switch section {
        case .menu:
            moveItem(at: sender.tag, offset: offset, in: &configuration.menuItems)
        case .newFile:
            moveItem(at: sender.tag, offset: offset, in: &configuration.newFileItems)
        }
    }

    private func moveItem(at index: Int, offset: Int, in items: inout [MenuConfigItem]) {
        guard items.indices.contains(index) else { return }
        let targetIndex = index + offset
        guard items.indices.contains(targetIndex) else { return }
        items.swapAt(index, targetIndex)
        saveAndRebuild()
    }

    private func rowCount(for section: Section) -> Int {
        switch section {
        case .menu: return configuration.menuItems.count
        case .newFile: return configuration.newFileItems.count
        }
    }

    @objc private func resetDefaults() {
        configuration = .defaultConfiguration
        saveAndRebuild()
    }

    @objc private func reloadConfiguration() {
        configuration = MenuConfigurationStore.load()
        rebuildRows()
    }

    private func saveAndRebuild() {
        do {
            try MenuConfigurationStore.save(configuration)
        } catch {
            showSaveError(error)
        }
        rebuildRows()
    }

    private func showSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "无法保存设置"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class RoundedPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private enum MenuCatalog {
    static let menuOrder = ["copyPath", "copyName", "openVSCode", "openCodex", "openCodexCLI", "openITerm", "newFile"]
    static let newFileOrder = ["txt", "markdown", "python", "shell", "html", "json", "csv"]

    static let menuTitles = [
        "copyPath": "复制路径",
        "copyName": "复制文件名",
        "openVSCode": "用 VS Code 打开",
        "openCodex": "用 Codex 打开",
        "openCodexCLI": "用 Codex CLI 打开",
        "openITerm": "用 iTerm2 打开",
        "newFile": "新建文件"
    ]

    static let menuSubtitles = [
        "copyPath": "复制选中项目路径，或在空白处复制当前目录路径。",
        "copyName": "复制选中项目名称；空白处复制当前目录名。",
        "openVSCode": "用 VS Code 打开选中项目或当前文件夹。",
        "openCodex": "用 Codex 打开当前目录；选中文件时打开其所在目录。",
        "openCodexCLI": "在 iTerm2 中进入对应目录并启动 Codex CLI。",
        "openITerm": "在 iTerm2 中打开对应目录。",
        "newFile": "显示可配置的新建文件类型子菜单。"
    ]

    static let newFileTitles = [
        "txt": "TXT",
        "markdown": "Markdown",
        "python": "Python",
        "shell": "Shell 脚本",
        "html": "HTML",
        "json": "JSON",
        "csv": "CSV"
    ]

    static let newFileSubtitles = [
        "txt": "空白文本文件。",
        "markdown": "Markdown 文档模板。",
        "python": "带 shebang 的 Python 脚本。",
        "shell": "带执行权限的 zsh 脚本。",
        "html": "基础 HTML 页面。",
        "json": "JSON 对象模板。",
        "csv": "空白 CSV 文件。"
    ]
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
            menuItems: MenuCatalog.menuOrder.map { MenuConfigItem(id: $0, enabled: true) },
            newFileItems: MenuCatalog.newFileOrder.map { MenuConfigItem(id: $0, enabled: true) }
        )
    }

    func normalized() -> MenuConfiguration {
        MenuConfiguration(
            version: 1,
            menuItems: Self.normalizedItems(menuItems, defaultOrder: MenuCatalog.menuOrder),
            newFileItems: Self.normalizedItems(newFileItems, defaultOrder: MenuCatalog.newFileOrder)
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
        let url = configurationURL()
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(MenuConfiguration.self, from: data)
        else {
            return .defaultConfiguration
        }

        return decoded.normalized()
    }

    static func save(_ configuration: MenuConfiguration) throws {
        let url = configurationURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.prettyPrinted.encode(configuration.normalized())
        try data.write(to: url, options: .atomic)
    }

    private static func configurationURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("dev.codex.MagicMenuLiteFinder.FinderExtension", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MagicMenuLiteFinder", isDirectory: true)
            .appendingPathComponent("MenuConfig.json")
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
