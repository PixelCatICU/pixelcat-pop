<p align="center">
  <img src="./Sources/PixelCatPop/Resources/pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# PixelCat Pop

PixelCat Pop 是一个原生 macOS 菜单栏工具箱，使用 SwiftUI、AppKit、ScreenCaptureKit 和 Apple Translation 构建。它把常用的翻译、截图标注、屏幕录制、应用清理和轻量系统监控放到菜单栏里，尽量保持低打扰、按需加载。

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
| 智能目标语言 | 中文和英文优先互译，其他语言翻译到默认目标语言 |
| 固定目标语言 | 可在设置里改为始终翻译到指定语言 |
| 翻译历史 | 可保留最近翻译记录，也可在设置中关闭或清空 |
| 截图标注 | 选择屏幕区域或吸附窗口后添加矩形、箭头、文字和马赛克，支持复制或保存 PNG |
| 实时马赛克强度 | 调节强度时会立即更新已选中的马赛克标注 |
| 屏幕录制 | 使用和截图一致的选择体验，可框选区域或吸附窗口录制 |
| HEVC MP4 导出 | 录屏保存为 `.mp4`，视频编码使用 H.265/HEVC，音频使用 AAC |
| 物理像素录制 | Retina 屏幕按显示器物理像素写入，避免逻辑点尺寸导致画面发糊 |
| 录制音频 | 可分别开启系统声音和麦克风声音 |
| 交互效果 | 录制时可播放鼠标点击声、键盘输入声，并显示点击波纹和输入区域 Zoom |
| 应用清理 | 选择或拖入 `.app` 后扫描相关偏好设置、缓存、容器、日志和应用支持文件，确认后移到废纸篓 |
| 菜单栏监控 | CPU、内存、磁盘、网络显示默认关闭，可按需开启；图标默认使用系统白色，可选择随 CPU/内存状态变色 |
| 多语言界面 | 设置界面支持中文 / English / 跟随系统 |

## 使用

菜单栏图标提供这些主要入口：

- 输入翻译
- 翻译剪贴板
- 截图标注
- 开始 / 停止录屏
- 应用清理
- 设置
- 退出

Debug 构建里会额外显示“重启”菜单项，方便开发期间快速重启；正式 Release 包不会依赖这个入口。

### 翻译

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

### 截图标注

从菜单栏选择“截图标注”后，PixelCat Pop 会显示全屏选择层：

- 鼠标悬停到可见窗口时会吸附并高亮窗口。
- 点击高亮窗口可直接截取整窗。
- 也可以自由拖拽选择任意区域。
- 编辑器支持矩形、箭头、文字和马赛克。
- 标注结果可复制到剪贴板或保存为 PNG。

### 屏幕录制

从菜单栏选择“开始录屏”后，会进入和截图一致的选择层：

- 点击吸附窗口录制该窗口区域。
- 拖拽区域录制所选区域。
- 再次点击菜单里的“停止录屏”结束录制。
- 输出文件保存到桌面，文件名形如 `PixelCatPop-Recording-YYYYMMDD-HHMMSS.mp4`。

录制写入 `.mp4` 容器，视频编码为 H.265/HEVC。HEVC 编码本身需要计算资源，但在 Apple Silicon 和较新的 Mac 上通常会走硬件编码；录屏区域越大、帧率越高、同时录制音频和交互效果越多，CPU/GPU/编码器压力也会越高。

### 应用清理

应用清理功能参考 AppCleaner 的核心流程：

- 用户主动选择或拖入应用。
- 根据 Bundle ID 扫描常见残留位置。
- 展示候选文件列表并允许取消勾选。
- 确认后使用系统废纸篓，不直接永久删除。

当前覆盖常见位置包括：

```text
应用本体
~/Library/Application Support
~/Library/Caches
~/Library/Preferences
~/Library/Saved Application State
~/Library/Logs
~/Library/Containers
~/Library/Group Containers
```

### 设置

设置界面按功能分组：

```text
通用
翻译
截图标注
录屏
交互效果
应用清理
菜单栏监控
```

菜单栏监控默认不采样 CPU、内存、磁盘和网络，只有在设置里打开对应显示项后才会定时刷新。图标默认保持系统模板色；打开“图标随状态变色”后，可以选择按 CPU 或内存占用改变图标颜色。

## 系统要求

- macOS 15 或更新版本。
- 截图标注使用 `SCScreenshotManager`，需要 macOS 15.2 或更新版本。
- Xcode / Swift 6 工具链。
- 已安装 Apple Translation 对应语言包。

权限说明：

- 翻译依赖 Apple Translation，语言包下载和可用语言由 macOS 管理。
- 全局监听双击 `Command-C` 可能需要辅助功能权限。
- 截图和录屏需要屏幕录制权限。
- 开启麦克风录制时需要麦克风权限。

如果翻译一直停在加载状态或提示语言不可用，请先打开系统自带“翻译”应用，或到系统设置里下载对应语言。

## 构建

建议使用完整 Xcode 工具链：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

构建 Debug：

```bash
swift build
```

构建测试：

```bash
swift build --build-tests
```

运行测试：

```bash
swift test
```

打包 Release App：

```bash
Scripts/package-app.sh
```

打包后的应用位于：

```text
dist/PixelCatPop.app
```

运行打包后的 `.app`：

```bash
open dist/PixelCatPop.app
```

也可以直接用 SwiftPM 运行：

```bash
swift run PixelCatPop
```

日常使用建议运行 `dist/PixelCatPop.app`。Apple Translation、屏幕录制权限和麦克风权限在正式 `.app` 包形态下更接近真实运行环境。

## 项目结构

```text
Sources/PixelCatPop/App/                 应用入口、AppDelegate、菜单栏生命周期
Sources/PixelCatPop/AppCleaner/          应用卸载残留扫描、勾选确认和移到废纸篓
Sources/PixelCatPop/Clipboard/           剪贴板读取和双击 Command-C 触发监听
Sources/PixelCatPop/InteractionEffects/  鼠标点击声、键盘输入声、波纹和 Zoom 效果
Sources/PixelCatPop/Recording/           录屏、系统声音、麦克风和视频写入
Sources/PixelCatPop/Resources/           图标和资源文件
Sources/PixelCatPop/Screenshot/          截图选择、窗口吸附、截图捕获和标注编辑器
Sources/PixelCatPop/Settings/            设置存储和设置界面
Sources/PixelCatPop/Shared/              共享模型、本地化、品牌资源和通用视图
Sources/PixelCatPop/SystemMonitor/       CPU、内存、磁盘、网络采样和菜单栏展示
Sources/PixelCatPop/Translation/         翻译服务、语言路由、翻译面板和历史记录
Tests/PixelCatPopTests/                  按功能域组织的测试
Scripts/package-app.sh                   macOS .app 打包脚本
Scripts/test-screenshot-editor.sh        截图编辑器辅助测试脚本
.github/workflows/ci.yml                 GitHub Actions 工作流
```

当前仍保留单个 SwiftPM target，避免早期拆分模块带来资源归属和访问级别成本。等录屏、截图、翻译、系统监控等功能边界稳定后，再考虑拆成独立 library target。

## 工作流

CI 会在 `main` 分支 push、pull request 或手动触发时执行：

```text
swift test
swift build -c release
Scripts/package-app.sh
```

并上传 `dist/PixelCatPop.app` 作为构建产物。

## 说明

PixelCat Pop 依赖 macOS 系统能力较多，部分行为受系统版本、权限状态、屏幕配置、语言包和硬件编码能力影响。

本项目仍处于早期迭代阶段，当前重点是把菜单栏工具箱里的高频功能做成稳定、低打扰、按需开启的体验。

## 开源协议

本项目采用 [GNU General Public License v3.0](./LICENSE) 开源协议。
