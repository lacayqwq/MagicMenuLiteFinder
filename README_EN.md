# MagicMenu

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <img src="App/Resources/MagicMenuLiteFinder-icon-preview.png" width="128" alt="MagicMenu icon">
</p>

Adds frequently used actions such as copying paths, opening developer tools, and creating files to the Finder context menu.

## Features

- Copy file paths or file names
- Open items with VS Code or Codex, and run Codex CLI or Claude Code in the selected terminal
- Create TXT, Markdown, Python, Shell, HTML, JSON, and CSV files
- Rename every menu item, enable or disable features, and reorder items
- Choose automatic, iTerm2, or macOS Terminal; automatic mode falls back when iTerm2 is unavailable

## Installation

Requires macOS 13 or later. Supports both Apple Silicon and Intel Macs.

1. If an older version is installed, quit it and remove `MagicMenuLiteFinder.app` from Applications to prevent duplicate entries.
2. Go to [Releases](https://github.com/lacayqwq/MagicMenu/releases/latest) and download `MagicMenu-v1.3.1-macos.zip`.
3. Unzip the archive and move `MagicMenu.app` to the Applications folder.
4. On first launch, right-click the app and choose **Open**.
5. Go to **System Settings > General > Login Items & Extensions > Finder Extensions** and enable `MagicMenu`.

> The release uses ad hoc code signing and is not notarized by Apple, so the first launch must use the right-click **Open** action.

## Usage

Right-click a file, folder, or empty area in Finder and choose the action you need.

Open `MagicMenu` from the Applications folder to choose a terminal, rename top-level and new-file menu items, enable or disable features, and reorder items. The default automatic mode prefers iTerm2 and uses macOS Terminal when iTerm2 is missing or cannot open. Leave an alias empty to use its built-in name. Creating a file never overwrites an existing file; name conflicts produce names such as `Untitled 2.ext`.

## Permissions and troubleshooting

- **The menu does not appear:** Make sure the Finder extension is enabled, then relaunch Finder. If needed, run `killall Finder` in Terminal.
- **Open with CC does nothing:** Make sure Claude Code is installed and that `claude --version` works in the selected terminal.
- **A new file is not ready to rename automatically:** Allow `MagicMenu` in **System Settings > Privacy & Security > Accessibility**. This permission is used only for automatic renaming.
- **A file cannot be created:** When first using Desktop, Documents, Downloads, or an external drive, allow the folder access request from macOS.

## Build from source

Xcode is required.

```sh
git clone https://github.com/lacayqwq/MagicMenu.git
cd MagicMenu
./build-and-install.sh
```

Run `./package-release.sh` to build release artifacts. See [CHANGELOG.md](CHANGELOG.md) for version history.
