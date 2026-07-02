# LocalVoice 本地语音 | macOS 离线语音输入与语音转文字

LocalVoice 是那种**装上后就会一直留在 Mac 里的语音输入工具**。按住快捷键，说话，松开，文字就会出现在当前应用里，你几乎不需要改变原来的工作方式。

它在 **Apple Silicon** 上结合 **MLX + Qwen3-ASR** 运行，提供 **离线语音转文字**、**中文和英文听写**、以及 **本地语音识别**，所有转录过程都在设备本地完成，不会把音频发送到云端。

如果你想要一款 **Mac 菜单栏语音输入工具**，既轻巧、私密，又足够适合每天高频使用，LocalVoice 就是为这个场景设计的。

[English README](README.md)

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-26%2B-brightgreen)](https://developer.apple.com/macos)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-orange)](https://www.apple.com/mac/)
[![MLX](https://img.shields.io/badge/MLX-Qwen3--ASR-blueviolet)](https://github.com/ml-explore/mlx)
[![Language](https://img.shields.io/badge/English-%E4%B8%AD%E6%96%87-lightgrey)](README.md)

<img src="Sources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="128" alt="LocalVoice 应用图标，适用于 macOS 离线语音输入与语音转文字">

## 目录

- [概览](#概览)
- [核心特性](#核心特性)
- [支持项目](#支持项目)
- [安装](#安装)
- [首次使用](#首次使用)
- [配置说明](#配置说明)
- [常见问题](#常见问题)
- [开发](#开发)
- [项目结构](#项目结构)
- [许可证](#许可证)

## 概览

LocalVoice 会把你的 Mac 变成一个轻量、私密、几乎不打扰工作的语音输入工具：

- 按住快捷键，说话，松开后文字直接输入到当前应用
- 支持中文、英文以及中英混合的本地转写
- 0.6B 模型适合追求速度，1.7B 模型适合追求准确率
- 优先使用原生文本注入，必要时自动降级到剪贴板方式
- 语音数据始终留在你的 Mac 上，不依赖云端服务

<table>
  <tr>
    <td><strong>按住</strong><br>使用 Fn / Globe 或自定义快捷键开始说话。</td>
    <td><strong>开口</strong><br>支持中文、英文以及中英混合输入。</td>
    <td><strong>继续工作</strong><br>文字直接进入你当前正在使用的应用。</td>
  </tr>
</table>

## 适用场景

- 写邮件、记笔记、提工单、写文档时，不必离开键盘
- 临时想到的内容可以立刻说出来，避免灵感流失
- 中文、英文或中英混合输入只需要一套工作流
- 对隐私敏感的工作、学习和个人使用场景都适合本地完成

## 为什么选择 LocalVoice

如果你想要一款真正适合日常使用的语音输入工具，LocalVoice 的优势在于：

- **够快** - 不打开网页、不切标签页、不走云端回传
- **够私密** - 转写始终留在你的 Mac 上
- **够专注** - 只做语音转文字这一件事，流程简单稳定

| 对比对象 | LocalVoice 的优势 |
| --- | --- |
| 云端听写 | 不走音频回传，不受网络影响，也没有云端政策风险 |
| 浏览器工具 | 不需要切标签页，不需要打开网页，不需要反复登录 |
| 系统自带听写 | 更适合中英文混合输入，也更贴合菜单栏常驻工作流 |
| 大而全的 AI 助手 | 只做“语音转文字”这一件事，启动更快，干扰更少 |
| 分应用快捷键方案 | 一个统一的按住说话流程，跨应用体验更稳定 |

## 核心特性

| 模块 | 说明 |
| --- | --- |
| 本地语音识别 | 使用 MLX 在设备本地完成转录 |
| 隐私优先 | 听写时音频不会离开你的 Mac |
| 中英文双语 | 支持中文、英文及中英混合输入 |
| 快捷键听写 | 支持 Fn / Globe 或自定义快捷键 |
| 文本注入 | 优先使用辅助功能，必要时自动回退剪贴板 |
| 模型管理 | 支持下载、断点续传、校验和删除模型 |
| 本地润色 | 可选使用本地 LLM 优化转写结果 |
| 菜单栏界面 | 轻量、快速，适合常驻使用 |

## 支持项目

如果 LocalVoice 对你有帮助，欢迎通过下面几种方式支持项目：

- 给仓库点一个 Star，方便更多人找到它
- 分享给需要 Mac 离线语音输入的人
- 通过应用内的「打赏」页支持后续开发

<p align="center">
  <img src="Sources/Resources/alipay_donate.jpg" width="240" alt="LocalVoice 打赏二维码，用于支持项目开发">
</p>

你的支持会帮助项目持续迭代、测试不同模型，并保持长期维护。

## 安装

### 系统要求

- macOS 26 或更高版本
- 仅支持 Apple Silicon：M1、M2、M3、M4 或更新机型
- 需要麦克风、辅助功能、输入监控权限
- 0.6B 模型约需 860 MB 磁盘空间和 1.5 GB 内存
- 1.7B 模型约需 1.8 GB 磁盘空间和 3.5 GB 内存

### 方式 1：下载 DMG

从 [Releases 页面](https://github.com/localvoice/local-llm-voice-input/releases) 下载 `LocalVoice.dmg`，打开后将 `LocalVoice.app` 拖到 `Applications`。

如果 macOS 首次启动时拦截：

```bash
xattr -dr com.apple.quarantine /Applications/LocalVoice.app
```

### 方式 2：从源码构建

```bash
git clone https://github.com/localvoice/local-llm-voice-input.git
cd local-llm-voice-input
./build.sh
```

## 首次使用

1. 从 `~/Applications` 启动 **LocalVoice**
2. 授予 **麦克风**、**辅助功能** 和 **输入监控** 权限
3. 在 **设置 → 模型** 中下载语音模型
4. 按住 **Fn / Globe** 开始说话
5. 松开按键后，转写结果会插入到当前应用

## 配置说明

### 快捷键

在 **设置 → 通用** 中可以修改按住说话的快捷键。

### 模型

在 **设置 → 模型** 中可以下载或切换以下模型：

| 模型 | 适用场景 | 大小 | 说明 |
| --- | --- | --- | --- |
| Qwen3-ASR 0.6B | 追求速度 | ~860 MB | 轻量、响应快 |
| Qwen3-ASR 1.7B | 追求准确率 | ~1.8 GB | 更适合大多数用户 |

下载源：

- HuggingFace
- HF Mirror
- ModelScope

### 文本输入

LocalVoice 优先使用辅助功能完成文本注入，在兼容性较差的应用中会自动回退到剪贴板粘贴。这样可以兼顾输入稳定性和应用适配性。

### 语言

应用界面支持中英文切换；语音识别本身支持中文、英文以及中英混合输入。

## 常见问题

### 转写是否完全离线？

是。转写过程完全在本地完成，只有首次下载模型时需要联网。

### 支持哪些 Mac？

当前仓库的构建目标是 macOS 26+，并且仅支持 Apple Silicon。

### 应该选择哪个模型？

如果你更看重速度，选 0.6B；如果你更看重准确率，选 1.7B。

### 为什么需要这些权限？

- 麦克风：采集语音用于识别
- 辅助功能：把转写内容输入到当前应用
- 输入监控：监听全局快捷键

## 开发

### 常用命令

```bash
./build.sh
./build.sh --build-only
./build.sh --dmg
./test.sh
./test_transcribe.sh
swift test
```

### 项目结构

- `Sources/App` - 应用生命周期与共享状态
- `Sources/UI` - 菜单栏、引导页、设置页与浮窗
- `Sources/Audio` - 录音与转写编排
- `Sources/Config` - 权限、语言、日志与设计配置
- `Sources/Assets.xcassets` - 应用图标与资源目录
- `Tests/VocalTypeTests` - 单元测试与集成测试

## 说明

- 首次下载模型时仍需要联网。
- 当前仓库的构建目标是 macOS 26+，不支持更早版本。

## 许可证

Apache 2.0，详见 [LICENSE](LICENSE)。
