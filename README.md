# MagicMenu

<p align="center">
  <strong>简体中文</strong> · <a href="README_EN.md">English</a>
</p>

<p align="center">
  <img src="App/Resources/MagicMenuLiteFinder-icon-preview.png" width="128" alt="MagicMenu 图标">
</p>

为 Finder 右键菜单添加复制路径、用开发工具打开和新建文件等常用操作。

## 功能

- 复制文件路径或文件名
- 用 VS Code、Codex 打开，或在所选终端中运行 Codex CLI 和 Claude Code
- 新建 TXT、Markdown、Python、Shell、HTML、JSON 和 CSV 文件
- 自定义所有菜单项名称，自由开关功能并拖动调整顺序
- 可选择自动、iTerm2 或 macOS 终端；自动模式在没有 iTerm2 时使用系统终端

## 安装

支持 macOS 13 及以上系统，适用于 Apple Silicon 和 Intel Mac。

1. 如果安装过旧版，请先退出并删除“应用程序”中的 `MagicMenuLiteFinder.app`，避免系统保留重复项。
2. 前往 [Releases](https://github.com/lacayqwq/MagicMenu/releases/latest)，下载 `MagicMenu-v1.3.1-macos.zip`。
3. 解压后将 `MagicMenu.app` 移到“应用程序”文件夹。
4. 首次启动时，右键 App 并选择“打开”。
5. 前往“系统设置 > 通用 > 登录项与扩展 > Finder 扩展”，启用 `MagicMenu`。

> Release 版本已签名，但尚未经过 Apple 公证，因此首次启动需要使用右键“打开”。

## 使用

在 Finder 中右键文件、文件夹或空白处，选择需要的操作即可。

打开“应用程序”中的 `MagicMenu` 可选择终端，修改一级菜单和新建文件项目的别名，并调整功能开关和顺序。终端默认设为“自动”：优先使用 iTerm2，未安装或无法打开时使用 macOS 自带终端。别名留空时恢复内置名称。新建文件时不会覆盖已有文件，同名时会自动生成 `Untitled 2.ext` 等名称。

## 权限与排障

- **菜单未出现**：确认 Finder 扩展已启用，然后重新打开 Finder；仍未出现时运行 `killall Finder`。
- **“用 CC 打开”无响应**：确认已安装 Claude Code，并能在所选终端中运行 `claude --version`。
- **未自动进入重命名**：在“系统设置 > 隐私与安全性 > 辅助功能”中允许 `MagicMenu`。该权限仅用于自动重命名。
- **无法新建文件**：首次在桌面、文稿、下载或外接磁盘中使用时，请允许 macOS 弹出的文件夹访问请求。

## 从源码构建

需要 Xcode。

```sh
git clone https://github.com/lacayqwq/MagicMenu.git
cd MagicMenu
./build-and-install.sh
```

构建 Release 附件可运行 `./package-release.sh`。版本变更记录见 [CHANGELOG.md](CHANGELOG.md)。
