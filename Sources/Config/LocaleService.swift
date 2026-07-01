//
// LocaleService.swift
// LocalVoice
//
// Localization strings (Chinese/English)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI
import Observation

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var isEffectivelyChinese: Bool {
        switch self {
        case .system: return NSLocale.preferredLanguages.first?.hasPrefix("zh") == true
        case .english: return false
        case .chinese: return true
        }
    }
}

// MARK: - Locale Service

@MainActor
@Observable
final class LocaleService {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    var isChinese: Bool { language.isEffectivelyChinese }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: raw) ?? .system
    }

    // MARK: - General

    var appName: String { isChinese ? "LocalVoice 本地语音" : "LocalVoice" }
    var recommended: String { isChinese ? "推荐" : "Recommended" }
    var cancel: String { isChinese ? "取消" : "Cancel" }
    var back: String { isChinese ? "返回" : "Back" }
    var retry: String { isChinese ? "重试" : "Retry" }
    var skip: String { isChinese ? "跳过" : "Skip" }
    var `continue`: String { isChinese ? "继续" : "Continue" }
    var settings: String { isChinese ? "设置..." : "Settings..." }
    var quit: String { isChinese ? "退出" : "Quit" }
    var done: String { isChinese ? "完成" : "Done" }
    var loading: String { isChinese ? "加载中..." : "Loading..." }
    var setLater: String { isChinese ? "稍后设置" : "Set Up Later" }
    var somethingWentWrong: String { isChinese ? "出现错误" : "Something went wrong" }
    var quitApp: String { isChinese ? "退出 LocalVoice" : "Quit LocalVoice" }
    var permissionUnknown: String { isChinese ? "未检查" : "Not checked" }
    var denied: String { isChinese ? "已拒绝" : "Denied" }
    var restricted: String { isChinese ? "受限" : "Restricted" }
    var failed: String { isChinese ? "失败" : "Failed" }
    var openSystemSettings: String { isChinese ? "打开系统设置..." : "Open System Settings" }
    var systemPermissions: String { isChinese ? "系统权限" : "System Permissions" }
    var settingsTitle: String { isChinese ? "偏好设置" : "Preferences" }
    var welcomeWindowTitle: String { isChinese ? "欢迎使用 LocalVoice" : "Welcome to LocalVoice" }
    var permissionsWindowTitle: String { isChinese ? "权限设置" : "Permissions" }
    var recordingWindowTitle: String { isChinese ? "录音中" : "Recording" }

    // MARK: - Appearance / Theme

    var appearance: String { isChinese ? "外观" : "Appearance" }
    var theme: String { isChinese ? "主题" : "Theme" }
    var themeSystem: String { isChinese ? "跟随系统" : "Follow System" }
    var themeLight: String { isChinese ? "浅色（牛油果）" : "Light (Avocado)" }
    var themeDark: String { isChinese ? "深色（竞速红）" : "Dark (Racing Red)" }

    // MARK: - Permission status helpers

    func permissionStatusText(_ status: PermissionStatus) -> String {
        switch status {
        case .unknown: return permissionUnknown
        case .granted: return granted
        case .denied: return denied
        case .restricted: return restricted
        }
    }

    func modelStatusText(_ phase: ModelDownloadPhase) -> String {
        switch phase {
        case .idle: return modelNotDownloaded
        case .fetching: return modelFetching
        case .downloading: return modelDownloading
        case .verifying: return modelVerifying
        case .completed: return modelCompleted
        case .retrying(let attempt, _): return isChinese ? "第\(attempt)/10次重试..." : "Retry \(attempt)/10..."
        case .failed(let error): return "\(failed): \(error)"
        }
    }

    // MARK: - Menu Bar

    var menuReady: String { isChinese ? "准备就绪" : "Ready to dictate" }
    var menuRecording: String { isChinese ? "录音中..." : "Recording..." }
    var menuTranscribing: String { isChinese ? "转录中..." : "Transcribing..." }
    var menuOffline: String { isChinese ? "本地运行，无需联网" : "Local & offline" }

    var menuMicGrant: String { isChinese ? "启用麦克风" : "Enable Microphone" }
    var menuAccGrant: String { isChinese ? "启用辅助功能" : "Open Accessibility" }
    var menuOverlayOn: String { isChinese ? "浮窗：开" : "Overlay: On" }
    var menuOverlayOff: String { isChinese ? "浮窗：关" : "Overlay: Off" }

    // MARK: - Welcome

    var welcomeTitle: String { isChinese ? "欢迎使用 LocalVoice" : "Welcome to LocalVoice" }
    var welcomeSubtitle: String { isChinese ? "你的声音，你的 Mac，完全离线。" : "Your voice, your Mac, fully offline." }
    var welcomeFeature1: String { isChinese ? "按住 Fn 键随时语音输入" : "Hold Fn to dictate anywhere" }
    var welcomeFeature2: String { isChinese ? "本地 AI 驱动 — 无需联网" : "Powered by local AI — no cloud" }
    var welcomeFeature3: String { isChinese ? "100% 隐私，数据不出 Mac" : "100% private, never leaves your Mac" }
    var getStarted: String { isChinese ? "开始使用" : "Get Started" }

    var setupPermissions: String { isChinese ? "权限设置" : "Setup Permissions" }
    var setupPermissionsDesc: String { isChinese ? "LocalVoice 需要两个系统权限才能正常工作。" : "LocalVoice needs two system permissions to work properly." }
    var microphone: String { isChinese ? "麦克风" : "Microphone" }
    var microphoneDesc: String { isChinese ? "用于捕获你的声音" : "To capture your voice" }
    var accessibility: String { isChinese ? "辅助功能" : "Accessibility" }
    var accessibilityDesc: String { isChinese ? "用于向其他应用输入文字" : "To type text into other apps" }
    var skipForNow: String { isChinese ? "稍后再说" : "Skip for now" }

    var downloadModel: String { isChinese ? "下载语音模型" : "Download Speech Model" }
    var downloadModelDesc: String { isChinese ? "LocalVoice 需要先下载本地 AI 模型，才能将语音转为文字。" : "LocalVoice needs a local AI model before it can transcribe speech." }
    var downloadSource: String { isChinese ? "下载源" : "Download Source" }
    var modelBilingual: String { isChinese ? "双语：中文、英文及中英混合" : "Bilingual: Chinese, English, and mixed-language" }
    var modelDownloaded: String { isChinese ? "模型已下载就绪" : "Model downloaded and ready" }
    var cancelDownload: String { isChinese ? "取消下载" : "Cancel Download" }
    var downloadModelBtn: String { isChinese ? "下载模型" : "Download Model" }
    var modelNotDownloaded: String { isChinese ? "未下载" : "Not downloaded" }
    var modelFetching: String { isChinese ? "获取文件列表..." : "Fetching file list..." }
    var modelDownloading: String { isChinese ? "下载中..." : "Downloading..." }
    var modelVerifying: String { isChinese ? "校验中..." : "Verifying..." }
    var modelCompleted: String { isChinese ? "已下载" : "Downloaded" }

    var allSet: String { isChinese ? "一切就绪！" : "You're all set!" }
    var allSetDesc: String { isChinese ? "按住 Fn 键开始说话。" : "Hold the Fn key and start speaking." }
    var quickTip: String { isChinese ? "小贴士" : "Quick Tip" }
    var quickTipDesc: String { isChinese ? "菜单栏图标显示使用状态。点击图标可快速操作或打开设置。" : "The menu bar icon shows your status. Click it for quick actions or to open settings." }
    var startUsing: String { isChinese ? "开始使用 LocalVoice" : "Start Using LocalVoice" }
    var grant: String { isChinese ? "授权" : "Grant" }

    // MARK: - Settings

    var settingsGeneral: String { isChinese ? "通用" : "General" }
    var settingsModel: String { isChinese ? "模型" : "Model" }
    var setupGuideSectionTitle: String { isChinese ? "设置向导" : "Setup Guide" }
    var openGuide: String { isChinese ? "打开向导" : "Open Guide" }
    var settingsText: String { isChinese ? "文字输入" : "Text Input" }
    var settingsPermissions: String { isChinese ? "权限" : "Permissions" }
    var settingsDonate: String { isChinese ? "打赏" : "Donate" }

    var languageLabel: String { isChinese ? "语言" : "Language" }
    var languageDesc: String { isChinese ? "应用界面语言（不影响语音识别语言）" : "App UI language (does not affect speech recognition)" }

    var launchAtLogin: String { isChinese ? "开机启动" : "Launch at Login" }
    var launchAtLoginDesc: String { isChinese ? "登录 Mac 后自动启动 LocalVoice" : "Automatically start LocalVoice after login" }
    var recordingOverlay: String { isChinese ? "录音浮窗" : "Recording Overlay" }
    var recordingOverlayDesc: String { isChinese ? "录音时显示浮动指示器" : "Show a floating indicator while recording" }
    var playSound: String { isChinese ? "提示音" : "Play Sound" }
    var playSoundDesc: String { isChinese ? "开始/停止录音时播放提示音" : "Play a sound when recording starts/stops" }

    var hotkey: String { isChinese ? "快捷键" : "Hotkey" }
    var hotkeyDesc: String { isChinese ? "按住该键开始录音，松开后转录" : "Hold to record, release to transcribe" }

    var sttEngine: String { isChinese ? "语音识别引擎" : "Speech-to-Text Engine" }
    var ramUsage: String { isChinese ? "内存占用" : "RAM Usage" }
    var downloadSize: String { isChinese ? "下载大小" : "Download Size" }
    var accuracy: String { isChinese ? "准确度" : "Accuracy" }
    var activeModel: String { isChinese ? "当前模型" : "Active Model" }
    var loadingModel: String { isChinese ? "加载模型中..." : "Loading model..." }
    var modelReady: String { isChinese ? "模型就绪" : "Model ready" }
    var speechToTextEngine: String { isChinese ? "语音识别引擎" : "Speech-to-Text Engine" }
    var fastAndLight: String { isChinese ? "轻量快速" : "Fast & Light" }
    var resume: String { isChinese ? "继续" : "Resume" }
    var partialDownloadHint: String { isChinese ? "检测到未完成的下载 — 重试将继续下载" : "Partial download available — Retry will resume" }
    var cleared: String { isChinese ? "已清除" : "Cleared" }
    var clear: String { isChinese ? "清除" : "Clear" }
    var clearRecordings: String { isChinese ? "清除录音" : "Clear Recordings" }
    var behavior: String { isChinese ? "行为" : "Behavior" }
    var aiRewriting: String { isChinese ? "AI 润色" : "AI Rewriting" }
    var aiRewritingDesc: String { isChinese ? "自动清理语气词并优化转录质量" : "Automatically clean up filler words and improve transcription quality" }
    var viewLog: String { isChinese ? "查看日志" : "View Log" }
    var debug: String { isChinese ? "调试" : "Debug" }
    var debugLog: String { isChinese ? "调试日志" : "Debug Log" }
    var logsLocation: String { isChinese ? "日志位置：~/Library/Application Support/com.vocaltype.app/debug.log" : "Logs are at ~/Library/Application Support/com.vocaltype.app/debug.log" }

    var sourceHuggingface: String { isChinese ? "全球下载（中国大陆可能较慢）" : "Global — may be slow in China" }
    var sourceMirror: String { isChinese ? "hf-mirror.com — 中国大陆推荐" : "hf-mirror.com — recommended in China" }
    var sourceModelscope: String { isChinese ? "modelscope.cn — 中国大陆最快" : "ModelScope.cn — fastest in China" }

    var textInjection: String { isChinese ? "文字注入方式" : "Text Injection Method" }
    var textInjectionAuto: String { isChinese ? "使用辅助功能 API，自动降级到剪贴板" : "Uses Accessibility API with clipboard fallback" }
    var textInjectionClip: String { isChinese ? "复制到剪贴板，手动粘贴" : "Copies to clipboard, user pastes manually" }
    var smartSpacing: String { isChinese ? "智能空格" : "Smart Spacing" }
    var smartSpacingDesc: String { isChinese ? "中英文之间自动添加空格" : "Auto-add spaces between Chinese & English" }
    var languagePref: String { isChinese ? "语言偏好" : "Language Preference" }
    var punctuation: String { isChinese ? "标点处理" : "Punctuation" }
    var punctSmart: String { isChinese ? "根据停顿自动添加" : "Adds punctuation based on pauses" }
    var punctManual: String { isChinese ? "仅当你说出标点时添加" : "Only adds punctuation you speak" }
    var punctNone: String { isChinese ? "不添加标点" : "No punctuation added" }

    var availableDisk: String { isChinese ? "可用磁盘空间" : "Available disk space" }
    var delete: String { isChinese ? "删除" : "Delete" }
    var download: String { isChinese ? "下载" : "Download" }

    var permissionsTitle: String { isChinese ? "权限" : "Permissions" }
    var permissionsDesc: String { isChinese ? "LocalVoice 需要以下权限才能正常工作。" : "LocalVoice needs the following permissions to function." }
    var permissionsPrivacy: String { isChinese ? "所有音频均在本地处理，不会离开你的设备。" : "All audio is processed locally. No data leaves your device." }
    var permissionsAcc: String { isChinese ? "允许 LocalVoice 自动输入文字，就像你使用键盘一样。" : "This allows LocalVoice to programmatically type text." }
    var permissionsCheck: String { isChinese ? "检测权限" : "Check Permissions" }
    var permissionsSetupTitle: String { isChinese ? "权限设置" : "Permissions Setup" }
    var permissionsSetupDesc2: String { isChinese ? "LocalVoice 需要两个系统权限才能正常工作，两者都是必须的。" : "LocalVoice needs two system permissions to function. Both are required." }
    var granted: String { isChinese ? "已授权" : "Granted" }
    var whyPermissions: String { isChinese ? "为什么需要这些权限？" : "Why these permissions?" }
    var privacyDesc: String { isChinese ? "LocalVoice 完全在你的 Mac 上运行。没有数据离开你的设备。需要麦克风权限来听到你的声音，辅助功能权限则让应用能向其他程序输入转录的文字。" : "LocalVoice runs entirely on your Mac. No data leaves your device. Microphone access is needed to hear you, and Accessibility access lets the app type the transcribed text into whatever app you're using." }
    var autoDetectDesc: String { isChinese ? "自动在中英文之间切换，无需手动选择。" : "Automatically switches between Chinese and English based on speech." }
    var microphoneAccess: String { isChinese ? "麦克风权限" : "Microphone Access" }
    var microphoneAccessDesc: String { isChinese ? "用于听取你的语音输入" : "Needed to hear your voice for dictation." }
    var accessibilityAccess: String { isChinese ? "辅助功能权限" : "Accessibility Access" }
    var accessibilityAccessDesc: String { isChinese ? "用于向其他应用输入转录的文字" : "Needed to type transcribed text into other applications." }
    var privacyPriority: String { isChinese ? "你的隐私是我们的首要关注。所有处理在设备本地完成，没有任何数据离开你的 Mac。" : "Your privacy is our priority. All processing happens on-device. No data ever leaves your Mac." }
    var grantAccess: String { isChinese ? "授权" : "Grant Access" }
    var hotkeyRecordingDesc: String { isChinese ? "按住 Fn/Globe 键开始录音，松开停止。" : "Hold Fn/Globe key to start recording. Release to stop." }

    // MARK: - Recording

    var transcribing: String { isChinese ? "转录中..." : "Transcribing..." }
    var recordingDuration: String { isChinese ? "录音时长" : "Recording" }
    var noSpeechText: String { isChinese ? "未检测到语音输入" : "No speech detected" }

    // MARK: - Enum descriptions

    func textInjectionMethodDescription(_ method: TextInjectionMethod) -> String {
        switch method {
        case .automatic: return textInjectionAuto
        case .clipboardOnly: return textInjectionClip
        }
    }

    func languageName(_ lang: LanguagePreference) -> String {
        switch lang {
        case .autoDetect: return isChinese ? "自动检测" : "Auto-detect"
        case .chinese: return isChinese ? "中文" : "Chinese"
        case .english: return isChinese ? "英文" : "English"
        }
    }

    func punctuationDescription(_ punct: PunctuationPreference) -> String {
        switch punct {
        case .smart: return punctSmart
        case .manualOnly: return punctManual
        case .none: return punctNone
        }
    }

    // MARK: - Source descriptions (Settings Model Tab)

    func downloadSourceDesc(_ source: ModelSource) -> String {
        switch source {
        case .huggingface: return sourceHuggingface
        case .huggingfaceMirror: return sourceMirror
        case .modelscope: return sourceModelscope
        }
    }

    // MARK: - Model Info

    func modelDisplayName(_ engine: STTEngine) -> String {
        if isChinese {
            let family = engine.is06B ? "通义千问 ASR 0.6B" : "通义千问 ASR 1.7B"
            let quant = engine.displayName.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? ""
            return "\(family) · \(quant)"
        }
        return engine.displayName
    }

    func modelDescription(_ engine: STTEngine) -> String {
        switch engine {
        case .qwen3ASR06B4bit:
            return isChinese ? "0.6B 超轻量，内存占用最小" : "0.6B ultra-light, lowest memory use"
        case .qwen3ASR06B5bit:
            return isChinese ? "0.6B 轻量，速度快" : "0.6B light, fast"
        case .qwen3ASR06B6bit:
            return isChinese ? "0.6B 均衡，速度与精度兼顾（推荐）" : "0.6B balanced, speed & accuracy (Recommended)"
        case .qwen3ASR06B8bit:
            return isChinese ? "0.6B 高精度，精度接近全精度" : "0.6B high quality, near full precision"
        case .qwen3ASR06BBf16:
            return isChinese ? "0.6B 全精度，精度最高但内存占用大" : "0.6B full precision, highest quality"
        case .qwen3ASR17B4bit:
            return isChinese ? "1.7B 超轻量，大模型最省内存" : "1.7B ultra-light, lowest memory for 1.7B"
        case .qwen3ASR17B5bit:
            return isChinese ? "1.7B 轻量，速度与大模型精度兼顾" : "1.7B light, good speed with 1.7B accuracy"
        case .qwen3ASR17B6bit:
            return isChinese ? "1.7B 均衡，精度高" : "1.7B balanced, high accuracy"
        case .qwen3ASR17B8bit:
            return isChinese ? "1.7B 高精度，精度最佳但内存占用大" : "1.7B high quality, best accuracy"
        }
    }
}
