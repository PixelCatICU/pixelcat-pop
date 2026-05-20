<p align="center">
  <img src="./Sources/PixelCatPop/Resources/pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# PixelCat Pop

## 简介

PixelCat Pop 是一个原生 macOS 菜单栏翻译工具，使用 SwiftUI 和 Apple 系统 Translation 框架构建，适合日常阅读文档、代码注释、网页内容和聊天文本时快速翻译。

它不是一个复杂翻译软件，而是一个轻量、顺手、贴近系统的小工具。当前版本重点解决三个场景：

- **快速剪贴板翻译**：复制文字后双击 `Command-C` 触发翻译，不需要切换到独立翻译应用。
- **手动输入翻译**：菜单栏打开输入窗口，输入内容后自动翻译。
- **中英文优先互译**：识别到中文优先翻译成英文，识别到英文优先翻译成中文；其他语言按设置里的默认目标语言翻译。

## 入口

- 官网：[pixelcat.icu](https://pixelcat.icu)
- YouTube：[@PixelCatICU](https://www.youtube.com/@PixelCatICU)
- GitHub：[PixelCatICU](https://github.com/PixelCatICU)
- X：[@PixelCatICU](https://x.com/PixelCatICU)

## 功能

| 功能 | 说明 |
| --- | --- |
| 双击 `Command-C` 翻译 | 监听剪贴板文本，连续复制两次后弹出翻译面板 |
| 输入翻译 | 从菜单栏打开输入面板，自行输入并自动翻译 |
| 截图标注 | 框选屏幕区域后添加矩形、箭头、文字和马赛克，并支持复制或保存 PNG |
| 智能目标语言 | 中文和英文优先互译，其他语言翻译到默认目标语言 |
| 固定目标语言 | 可在设置里改为始终翻译到指定语言 |
| 玻璃面板 | 浮动面板使用系统材质效果，默认显示在屏幕中央 |
| 面板置顶 | 右上角固定按钮可让面板保持显示 |
| 一键清空 | 输入框内置清除按钮 |
| 复制译文 | 译文旁边提供复制按钮 |
| 朗读文本 | 支持朗读输入内容和译文 |
| 翻译历史 | 默认保留最近 20 条翻译记录 |
| 多语言界面 | 设置界面支持中文 / English / 跟随系统 |

## 翻译逻辑

智能模式：

- 中文文本翻译为英语。
- 英文文本翻译为中文。
- 其他语言翻译为设置中的默认目标语言。

固定模式：

- 所有文本都翻译为设置中选择的目标语言。

当前目标语言选项包括：

```text
中文、英语（美国）、日语、韩语、法语、德语、西班牙语
```

## 系统要求

- macOS 15 或更新版本。
- Xcode / Swift 6 工具链。
- 已安装 Apple Translation 对应语言包。

语言包由 macOS 管理。如果一直显示正在翻译或提示语言不可用，请先打开系统自带的“翻译”应用，或到系统设置中下载对应语言。

全局监听 `Command-C` 可能需要授予辅助功能权限。

截图标注需要 macOS 15.2 或更新版本，并需要授予屏幕录制权限。PixelCat Pop 只在用户主动选择截图标注时截取所选区域，不会自动保存截图历史。

## 构建

运行测试：

```bash
swift test
```

构建 Release 可执行文件：

```bash
swift build -c release
```

打包菜单栏 App：

```bash
Scripts/package-app.sh
```

打包后的应用位于：

```text
dist/PixelCatPop.app
```

## 运行

推荐运行打包后的 `.app`：

```bash
open dist/PixelCatPop.app
```

也可以直接用 SwiftPM 运行：

```bash
swift run PixelCatPop
```

说明：

- 日常使用建议运行 `dist/PixelCatPop.app`。
- 直接运行 SwiftPM 可执行文件更适合调试。
- Apple Translation 在正式 `.app` 包形态下更接近真实运行环境。

## 项目结构

```text
Sources/PixelCatPop/App/             应用入口、AppDelegate、菜单栏生命周期
Sources/PixelCatPop/Clipboard/       剪贴板读取和双击 Command-C 触发监听
Sources/PixelCatPop/Settings/        设置存储和设置界面
Sources/PixelCatPop/Shared/          共享模型、本地化、品牌资源和通用视图
Sources/PixelCatPop/Screenshot/      截图选择、截图捕获和标注编辑器
Sources/PixelCatPop/Translation/     翻译服务、语言路由、翻译面板和历史记录
Sources/PixelCatPop/Resources/       图标和资源文件
Tests/PixelCatPopTests/              按功能域组织的测试
Scripts/package-app.sh               macOS .app 打包脚本
.github/workflows/ci.yml             GitHub Actions 工作流
```

后续新增大功能时优先按功能域建目录，例如：

```text
Sources/PixelCatPop/Recording/           录屏、系统声音、麦克风和视频写入
Sources/PixelCatPop/InteractionEffects/  鼠标点击声、键盘输入声、波纹和 Zoom 效果
Sources/PixelCatPop/Permissions/         屏幕录制、麦克风、辅助功能等权限引导
```

当前仍保留单个 SwiftPM target，避免早期拆分模块带来资源归属和访问级别成本。等录屏、截图、翻译等功能边界稳定后，再考虑拆成独立 library target。

## 工作流

当前 CI 会在 `main` 分支 push、pull request 或手动触发时执行：

```text
swift test
swift build -c release
Scripts/package-app.sh
```

并上传 `dist/PixelCatPop.app` 作为构建产物。

## 说明

PixelCat Pop 依赖 macOS 系统翻译能力，因此翻译质量、可用语言和语言包下载流程由 Apple Translation 框架决定。

本项目目前处于早期迭代阶段，重点是把菜单栏翻译、输入翻译、语言路由和浮动面板体验打磨稳定。

## 开源协议

本项目采用 [GNU General Public License v3.0](./LICENSE) 开源协议。
