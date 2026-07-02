# MagicMenu Lite Finder

这是一个 Finder Sync Extension 版本，目标是把常用功能放到 Finder 右键菜单里，而不是放在“服务/快速操作”二级菜单中。

## 正式版说明

这是当前正式版。新建文件后会先让 Finder 选中新文件，再模拟按下 `Return` 进入重命名。

这个行为需要 macOS 辅助功能权限。第一次使用时如果没有进入重命名，打开“系统设置 > 隐私与安全性 > 辅助功能”，允许 `MagicMenuLiteFinder`，然后再试一次。安装脚本会给 App 加一个稳定的本地签名要求，减少重装后辅助功能授权失效的情况。

## 功能

- `复制路径`
- `复制文件名`
- `用 VS Code 打开`
- `用 Codex 打开`
- `用 Codex CLI 打开`
- `用 iTerm2 打开`
- `新建文件`
  - TXT
  - Markdown
  - Python
  - Shell 脚本
  - HTML
  - JSON
  - CSV

打开 `/Applications/MagicMenuLiteFinder.app` 会显示设置窗口，可以配置一级菜单和“新建文件”子菜单中各功能的开启/关闭和顺序。设置会立即保存；平时使用 Finder 右键菜单时不需要打开设置窗口。

右键空白处时，菜单按当前 Finder 目录处理：

- `复制当前目录路径` 会复制当前文件夹路径
- `复制当前目录名` 会复制当前文件夹名称
- `用 VS Code 打开` 会用 VS Code 打开当前文件夹
- `用 Codex 打开` 会用 Codex 打开当前文件夹
- `用 Codex CLI 打开` 会在 iTerm2 中进入当前文件夹并启动 Codex CLI
- `用 iTerm2 打开` 会用 iTerm2 打开当前文件夹
- `新建文件` 会在当前文件夹里创建

右键文件或文件夹时，`复制路径` 会复制选中项目路径；`复制文件名` 会复制选中项目名称；`用 VS Code 打开` 会打开选中项目；`用 Codex 打开` 和 `用 Codex CLI 打开` 会打开选中项目所在文件夹；`用 iTerm2 打开` 会打开选中项目所在文件夹；`新建文件` 会创建在选中项目所在的文件夹里。若同名文件已存在，会自动使用 `Untitled 2.ext` 这样的名字，避免覆盖。

## 安装 Xcode

如果机器上还没有 Xcode，请先在 App Store 里安装。安装完成后第一次打开 Xcode，按提示同意协议并安装额外组件。

## 构建和安装

Xcode 安装完成后，在终端运行：

```sh
cd /Users/linchengyu/Documents/Codex/2026-07-01/ssllix67-iboysoft-magicmenu-https-github-com
chmod +x build-and-install.sh
./build-and-install.sh
```

如果 Xcode 要求签名团队：

1. 打开 `MagicMenuLiteFinder.xcodeproj`
2. 选择项目 `MagicMenuLiteFinder`
3. 分别进入 `MagicMenuLiteFinder` 和 `MagicMenuLiteFinderExtension` 两个 target
4. 在 `Signing & Capabilities` 里选择你的 Apple ID Team
5. 再运行 `./build-and-install.sh`

## 启用扩展

构建安装后：

1. 打开 `/Applications/MagicMenuLiteFinder.app`
2. 点击“尝试启用扩展”
3. 打开“系统设置 > 登录项与扩展 > Finder 扩展”
4. 启用 `MagicMenu Lite`
5. 运行 `killall Finder` 或重新打开 Finder

## 说明

Finder Sync Extension 的菜单显示由 Finder 控制。相比 Services 版本，它更接近一级右键菜单；但 macOS 仍可能根据系统版本、启用状态和 Finder 当前上下文调整显示位置。

Finder Sync Extension 必须保持沙盒，否则 macOS 会拒绝加载。为了让“新建文件”能写入当前 Finder 目录，本项目使用沙盒扩展显示菜单，把新建文件请求写入扩展容器，再唤起非沙盒主 App 执行。

新建文件时，Finder 扩展会短暂唤起主 App 创建文件；创建完成后主 App 会自动退出，不需要常驻后台。

如果第一次在 `桌面`、`文稿`、`下载` 或外接/网络磁盘里新建文件，macOS 可能会弹出访问权限提示；允许后即可继续使用。失败时主 App 会弹窗显示具体错误，并把错误文本放入剪贴板。
