# MagicMenu Lite Finder

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <img src="App/Resources/MagicMenuLiteFinder-icon-preview.png" width="128" alt="MagicMenu Lite Finder icon">
</p>

Adds frequently used actions such as copying paths, opening developer tools, and creating files to the Finder context menu.

## Features

- Copy file paths or file names
- Open items with VS Code, Codex, Codex CLI, or iTerm2
- Create TXT, Markdown, Python, Shell, HTML, JSON, and CSV files
- Enable, disable, and reorder menu items

## Installation

Requires macOS 13 or later. Supports both Apple Silicon and Intel Macs.

1. Go to [Releases](https://github.com/lacayqwq/MagicMenuLiteFinder/releases/latest) and download `MagicMenuLiteFinder-v1.1.0-macos.zip`.
2. Unzip the archive and move `MagicMenuLiteFinder.app` to the Applications folder.
3. On first launch, right-click the app and choose **Open**.
4. Go to **System Settings > General > Login Items & Extensions > Finder Extensions** and enable `MagicMenu Lite`.

> The release uses ad hoc code signing and is not notarized by Apple, so the first launch must use the right-click **Open** action.

## Usage

Right-click a file, folder, or empty area in Finder and choose the action you need.

Open `/Applications/MagicMenuLiteFinder.app` to enable, disable, or reorder menu items. Creating a file never overwrites an existing file; name conflicts produce names such as `Untitled 2.ext`.

## Permissions and troubleshooting

- **The menu does not appear:** Make sure the Finder extension is enabled, then relaunch Finder. If needed, run `killall Finder` in Terminal.
- **A new file is not ready to rename automatically:** Allow `MagicMenuLiteFinder` in **System Settings > Privacy & Security > Accessibility**. This permission is used only for automatic renaming.
- **A file cannot be created:** When first using Desktop, Documents, Downloads, or an external drive, allow the folder access request from macOS.

## Build from source

Xcode is required.

```sh
git clone https://github.com/lacayqwq/MagicMenuLiteFinder.git
cd MagicMenuLiteFinder
./build-and-install.sh
```

Run `./package-release.sh` to build release artifacts. See [CHANGELOG.md](CHANGELOG.md) for version history.
