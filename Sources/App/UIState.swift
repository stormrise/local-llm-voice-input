//
// UIState.swift
// LocalVoice
//
// Central app state management (settings, recording, models)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI
import Observation
import AVFoundation

// MARK: - App State

@MainActor
@Observable
final class AppState {
    var appPhase: AppPhase = .launching
    var menuBarState: MenuBarState = .idle
    var recordingState: RecordingState = .idle
    var settings: AppSettings = .init()
    var permissions: PermissionState = .init()
    var models: ModelState = .init()
    var showSettings: Bool = false
    var showWelcome: Bool = false

    /// Partial transcription text for real-time display during recording
    var partialTranscription: String = ""

    // -- Partial transcription (incremental full-audio re-transcription) --

    /// In-flight partial transcription task — cancelled when new audio arrives.
    private var partialTranscriptionTask: Task<Void, Never>?
    /// Timer that drives periodic partial transcription every 1.5s while recording.
    private var partialTranscriptionTimer: Timer?
    /// Sample count at last partial run — skip if no new audio accumulated.
    private var lastPartialLength: Int = 0

    /// Whether the transcription model is loaded and ready
    var isModelLoaded: Bool = false
    /// Whether the model is currently being loaded (for UI feedback)
    var isModelLoading: Bool = false

    /// Locale / i18n service for bilingual UI
    let locale = LocaleService()

    /// App-wide configuration loaded from JSON (bundle + user override).
    var config: AppConfig

    // -- Services --

    var modelDownloadService: ModelDownloadService?
    let audioRecorder: AudioRecorder
    let hotkeyMonitor = HotkeyMonitor()
    let textInjector: TextInjector
    let transcriptionService: TranscriptionServiceProtocol = TranscriptionServiceFactory.make(engine: .qwen3ASR06B6bit)
    let textRewriter = TextRewriter()
    let overlayController = OverlayController()

    // -- Initialization --

    /// Delayed service initialization to avoid CGEventTap race on app launch.
    /// The hotkey monitor needs the app's run loop to be fully active before creating the tap,
    /// so we wait 1.5s after construction before starting services.
    init() {
        let loadedConfig = AppConfig.load()
        self.config = loadedConfig
        audioRecorder = AudioRecorder(config: loadedConfig)
        textInjector = TextInjector(config: loadedConfig)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppLogger.shared.info("🚀 Delayed service initialization")
                self.initializeServices()
            }
        }
    }

    // -- Lifecycle --

    func checkFirstLaunch() {
        if !config.onboarding.hasCompletedSetup {
            appPhase = .firstLaunch
            showWelcome = true
        } else {
            appPhase = .running
        }
    }

    func completeOnboarding() {
        config.onboarding.hasCompletedSetup = true
        config.save()
        appPhase = .running
        showWelcome = false
        // SwiftUI Window scenes don't auto-dismiss — close the welcome window
        for window in NSApp.windows {
            if window.title.contains("Welcome") || window.identifier?.rawValue == "welcome" {
                window.close()
            }
        }
    }

    /// Re-open the onboarding wizard (for re-running setup guide from Settings).
    func resetOnboarding() {
        config.onboarding.hasCompletedSetup = false
        config.save()
        appPhase = .firstLaunch
        showWelcome = true
        AppLogger.shared.info("🔄 Onboarding reset — opening welcome window")
    }

    func initializeServices() {
        initializeDownloadService()
        checkDownloadedModelsOnDisk()
        startEngine()
        loadModelIfDownloaded()
        requestMicrophonePermission()
    }

    /// Request microphone permission proactively at startup so the first
    /// hotkey press doesn't block on the permission prompt.
    private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                self.permissions.microphone = granted ? .granted : .denied
                AppLogger.shared.info("Microphone permission: \(granted ? "granted" : "denied")")
            }
        }
    }

    private func initializeDownloadService() {
        guard modelDownloadService == nil else { return }
        modelDownloadService = ModelDownloadService(state: self)
        modelDownloadService?.refreshPartialState()
        modelDownloadService?.refreshDiskSpace()
    }

    /// Check which models exist on disk and mark them as downloaded.
    /// This is needed because `downloadedEngines` is in-memory and empty on restart.
    private func checkDownloadedModelsOnDisk() {
        modelDownloadService?.checkDownloadedModelsOnDisk()
    }

    // -- Engine --

    /// Start the dictation engine: hotkey + audio + transcription.
    private func startEngine() {
        AppLogger.shared.info("🚀 Starting dictation engine...")
        hotkeyMonitor.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }
        hotkeyMonitor.onKeyUp = { [weak self] in
            self?.handleKeyUp()
        }
        let keyCode = settings.hotkey.keyCode ?? UInt32.fnKey
        hotkeyMonitor.start(keyCode: keyCode)
    }

    // -- Model Loading --

    /// Load the transcription model if it's already downloaded but not yet loaded.
    /// Called on app startup to enable immediate dictation if the model is ready.
    func loadModelIfDownloaded() {
        guard !isModelLoaded, !isModelLoading else { return }
        guard let downloadService = modelDownloadService else { return }
        var engine = settings.sttEngine
        // If selected engine isn't downloaded, switch to one that is
        if !models.isDownloaded(engine) {
            if let downloaded = STTEngine.allCases.first(where: { models.isDownloaded($0) }) {
                engine = downloaded
                settings.sttEngine = downloaded
                AppLogger.shared.info("Switched active engine to \(downloaded.rawValue) (selected engine not downloaded)")
            } else {
                AppLogger.shared.info("No downloaded models found, skipping model load")
                return
            }
        }

        let modelDir = downloadService.modelDirectory(for: engine)
        AppLogger.shared.info("Loading model from \(modelDir.path)")
        isModelLoading = true
        menuBarState = .idle  // will update when loaded

        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriptionService.loadModel(at: modelDir)
                await MainActor.run {
                    self.isModelLoaded = true
                    self.isModelLoading = false
                    AppLogger.shared.info("✅ Model loaded on startup")
                }
            } catch {
                await MainActor.run {
                    self.isModelLoaded = false
                    self.isModelLoading = false
                    AppLogger.shared.error("Failed to load model on startup: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Load the transcription model after a successful download.
    /// Called by ModelDownloadService when download completes.
    func loadModelAfterDownload(engine: STTEngine) {
        guard !isModelLoaded, !isModelLoading else { return }
        guard let downloadService = modelDownloadService else { return }

        let modelDir = downloadService.modelDirectory(for: engine)
        isModelLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriptionService.loadModel(at: modelDir)
                await MainActor.run {
                    self.isModelLoaded = true
                    self.isModelLoading = false
                    AppLogger.shared.info("✅ Model loaded after download")
                }
            } catch {
                await MainActor.run {
                    self.isModelLoaded = false
                    self.isModelLoading = false
                    AppLogger.shared.error("Failed to load model after download: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Switch the active transcription model.
    /// Unloads the current model and loads the new one if downloaded.
    func switchModel(to engine: STTEngine) {
        settings.sttEngine = engine

        // Unload current model
        transcriptionService.unloadModel()
        isModelLoaded = false
        isModelLoading = false

        // If the new engine is already downloaded, load it
        guard let downloadService = modelDownloadService else { return }
        guard models.isDownloaded(engine) else { return }

        let modelDir = downloadService.modelDirectory(for: engine)
        isModelLoading = true

        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriptionService.loadModel(at: modelDir)
                await MainActor.run {
                    self.isModelLoaded = true
                    self.isModelLoading = false
                    AppLogger.shared.info("✅ Model loaded after switch to \(engine.rawValue)")
                }
            } catch {
                await MainActor.run {
                    self.isModelLoaded = false
                    self.isModelLoading = false
                    AppLogger.shared.error("Failed to load model after switch: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Called when the hotkey is pressed — start recording.
    /// Microphone permission is requested proactively at startup
    /// (via `requestMicrophonePermission()`), so this path is fast.
    private func handleKeyDown() {
        AppLogger.shared.info("🎙️ handleKeyDown — modelLoaded=\(isModelLoaded), micPermission=\(permissions.microphone)")

        guard permissions.microphone == .granted else {
            AppLogger.shared.warn("⚠️ Microphone permission not granted, cannot start recording")
            menuBarState = .error("Microphone permission not granted")
            return
        }

        startRecording()
    }

    /// Actually start audio recording (called after permissions confirmed).
    private func startRecording() {
        do {
            try audioRecorder.start()
            AppLogger.shared.info("State: idle → recording")
            recordingState = .recording(RecordingInfo(startTime: Date()))
            menuBarState = .recording
            overlayController.show(state: self)
            AppLogger.shared.info("✅ Recording started")

            // Start partial transcription timer for live preview in overlay
            partialTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: config.partialTranscription.intervalSeconds, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.runPartialTranscription()
                }
            }
        } catch {
            AppLogger.shared.error("❌ Failed to start recording: \(error.localizedDescription)")
            recordingState = .failed(error.localizedDescription)
            menuBarState = .error(error.localizedDescription)
        }
    }

    /// Run a partial transcription of the audio accumulated so far.
    ///
    /// Called periodically by `partialTranscriptionTimer` while recording.
    /// Cancels any in-flight partial task, caps audio at ~20s, and updates
    /// `partialTranscription` on success. Failures are non-critical and silently ignored.
    private func runPartialTranscription() async {
        // Snapshot current audio without stopping recording
        let samples = audioRecorder.currentSamples
        guard samples.count > config.partialTranscription.minSamplesForPartial else { return }
        guard samples.count > lastPartialLength else { return } // skip if no new audio
        lastPartialLength = samples.count

        // Cancel previous in-flight partial transcription
        partialTranscriptionTask?.cancel()

        // Cap to keep inference time bounded
        let cappedSamples = Array(samples.suffix(config.partialTranscription.maxSamplesCapped))

        let wavData = audioRecorder.makeWAVData(samples: cappedSamples, sampleRate: config.recording.sampleRate)

        partialTranscriptionTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let languageHint: String? = {
                    switch settings.language {
                    case .autoDetect: return nil
                    case .chinese: return "Chinese"
                    case .english: return "English"
                    }
                }()
                let text = try await self.transcriptionService.transcribe(audioData: wavData, language: languageHint)
                try Task.checkCancellation()
                self.partialTranscription = text
                AppLogger.shared.debug("📡 Partial: \(text.prefix(20))")
            } catch {
                // Partial failure is non-critical — ignore cancellation and model errors
                if !(error is CancellationError) {
                    AppLogger.shared.debug("⚠️ Partial transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Called when the hotkey is released — stop, transcribe, inject.
    private func handleKeyUp() {
        // Stop silence detection — we're about to process the final buffer
        audioRecorder.stopSilenceDetection()

        // Cancel partial transcription timer and any in-flight partial task
        partialTranscriptionTimer?.invalidate()
        partialTranscriptionTimer = nil
        partialTranscriptionTask?.cancel()
        partialTranscriptionTask = nil
        lastPartialLength = 0
        partialTranscription = ""

        AppLogger.shared.info("⏹️ handleKeyUp — isRecording=\(audioRecorder.isRecording)")
        guard audioRecorder.isRecording else { return }

        guard let audioData = audioRecorder.stop() else {
            recordingState = .idle
            menuBarState = .idle
            overlayController.hide()
            return
        }

        // Audio diagnostics: log peak amplitude and non-zero sample count
        // WAV format: 44-byte header followed by Int16 PCM samples
        let wavHeaderSize = 44
        let sampleCount = audioData.count > wavHeaderSize ? (audioData.count - wavHeaderSize) / 2 : 0
        let peak: Int16
        let nonZeroCount: Int
        if sampleCount > 0 {
            let samples16 = audioData.withUnsafeBytes { ptr in
                Array(UnsafeBufferPointer(
                    start: ptr.baseAddress!.advanced(by: wavHeaderSize).assumingMemoryBound(to: Int16.self),
                    count: sampleCount
                ))
            }
            peak = samples16.map { abs($0) }.max() ?? 0
            nonZeroCount = samples16.filter { abs($0) > 10 }.count
        } else {
            peak = 0
            nonZeroCount = 0
        }
        AppLogger.shared.info("🎧 Audio: \(sampleCount) samples (\(audioData.count) raw bytes), peak=\(peak), nonZero=\(nonZeroCount)/\(sampleCount)")

        saveDebugRecording(audioData)

        AppLogger.shared.info("State: recording → transcribing")
        recordingState = .transcribing
        menuBarState = .transcribing

        Task { [weak self] in
            guard let self else { return }

            // Check if model is loaded before attempting transcription
            guard transcriptionService.isLoaded else {
                recordingState = .failed("Model not loaded. Please download or wait for model to load.")
                menuBarState = .error("Model not loaded")
                overlayController.hide()
                try? await Task.sleep(for: .seconds(3))
                if recordingState != .idle {
                    recordingState = .idle
                    menuBarState = .idle
                }
                return
            }

            do {
                let languageHint: String? = {
                    switch settings.language {
                    case .autoDetect: return nil
                    case .chinese: return "Chinese"
                    case .english: return "English"
                    }
                }()
                let text = try await transcriptionService.transcribe(audioData: audioData, language: languageHint)

                // Debug: show exact text with visible whitespace
                let debugText = text.replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\t", with: "\\t")
                AppLogger.shared.info("📄 Raw transcription: |\(debugText)|")

                // Rewrite transcription text (remove fillers, correct errors, format)
                let rewrittenText: String
                if settings.enableTextRewriting {
                    rewrittenText = await textRewriter.rewrite(text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if rewrittenText != text {
                        AppLogger.shared.info("✏️ Rewrote: \"\(text.prefix(30))\" → \"\(rewrittenText.prefix(30))\"")
                    }
                } else {
                    rewrittenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Debug: show exact text with visible whitespace
                let debugRewritten = rewrittenText.replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\t", with: "\\t")
                AppLogger.shared.info("📄 Final inject text: |\(debugRewritten)|")

                if rewrittenText.isEmpty {
                    recordingState = .idle
                    menuBarState = .idle
                    overlayController.hide()
                    return
                }

                recordingState = .complete(rewrittenText)
                overlayController.hide()

                // Inject text into the current app
                try await textInjector.inject(rewrittenText, method: settings.textInjectionMethod)
                AppLogger.shared.info("✅ Text injected: \(rewrittenText.prefix(50))...")

                // Brief delay before returning to idle
                try await Task.sleep(for: .seconds(0.5))
                recordingState = .idle
                menuBarState = .idle

            } catch {
                AppLogger.shared.error("❌ Text injection failed: \(error.localizedDescription)")
                recordingState = .failed(error.localizedDescription)
                menuBarState = .error(error.localizedDescription)
                overlayController.hide()

                // Auto-dismiss error after 3s
                try? await Task.sleep(for: .seconds(3))
                if recordingState != .idle {
                    recordingState = .idle
                    menuBarState = .idle
                }
            }
        }
    }

    /// Fire-and-forget text injection (same path as Fn release).
    private func injectText(_ text: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.textInjector.inject(text, method: self.settings.textInjectionMethod)
            } catch {
                AppLogger.shared.error("❌ Text injection failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Debug Recording

    private func saveDebugRecording(_ wavData: Data) {
        let debugDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.vocaltype.app/debug_recordings")
        try? FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

        // Rotate: keep max 10 WAV files
        let existingFiles = (try? FileManager.default.contentsOfDirectory(
            at: debugDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        let wavFiles = existingFiles
            .filter { $0.pathExtension == "wav" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return dateA < dateB
            }

        // Delete oldest files beyond the 10-file limit
        let toDelete = max(0, wavFiles.count - 9) // keep room for the new file
        for i in 0..<toDelete {
            try? FileManager.default.removeItem(at: wavFiles[i])
        }

        // Save new file
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = df.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp).wav"
        let fileURL = debugDir.appendingPathComponent(filename)

        do {
            try wavData.write(to: fileURL)
            AppLogger.shared.info("💾 Saved debug recording: \(filename) (\(wavData.count) bytes)")
        } catch {
            AppLogger.shared.error("❌ Failed to save debug recording: \(error.localizedDescription)")
        }
    }

    /// Cancel the current recording — stops the audio recorder, resets state,
    /// and hides the overlay. Called from the Cancel button or hotkey cancel.
    func cancelRecording() {
        // Stop silence detection before accessing the buffer
        audioRecorder.stopSilenceDetection()

        // Cancel partial transcription timer and any in-flight task
        partialTranscriptionTimer?.invalidate()
        partialTranscriptionTimer = nil
        partialTranscriptionTask?.cancel()
        partialTranscriptionTask = nil
        lastPartialLength = 0
        partialTranscription = ""

        AppLogger.shared.info("🚫 Recording cancelled")
        _ = audioRecorder.stop()
        recordingState = .idle
        menuBarState = .idle
        overlayController.hide()
    }

    /// Refresh the hotkey binding when settings change.
    func refreshHotkey() {
        let keyCode = settings.hotkey.keyCode ?? UInt32.fnKey
        if hotkeyMonitor.isMonitoring {
            hotkeyMonitor.updateKeyCode(keyCode)
        } else {
            hotkeyMonitor.start(keyCode: keyCode)
        }
    }
}

// MARK: - App Phase

enum AppPhase {
    case launching
    case firstLaunch
    case running
}

// MARK: - Menu Bar State

enum MenuBarState: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)

    var sfSymbol: String {
        switch self {
        case .idle: return "mic.fill"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .error: return "mic.slash.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .idle: return .secondary
        case .recording: return .appPrimary
        case .transcribing: return .appWarning
        case .error: return .appError
        }
    }
}

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording(RecordingInfo)
    case transcribing
    case complete(String)
    case failed(String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.recording(let a), .recording(let b)): return a.startTime == b.startTime
        case (.transcribing, .transcribing): return true
        case (.complete(let a), .complete(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .recording(let info): return "Recording \(info.durationFormatted)"
        case .transcribing: return "Transcribing..."
        case .complete(let text): return text.isEmpty ? "No speech detected" : "Done"
        case .failed(let error): return error
        }
    }
}

struct RecordingInfo {
    let startTime: Date
    var duration: TimeInterval { Date().timeIntervalSince(startTime) }
    var durationFormatted: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - App Settings

/// All settings are backed by UserDefaults so they survive app restarts.
/// Keys are prefixed with "localvoice_" to avoid conflicts.
struct AppSettings {
    // MARK: Keys
    private enum Keys {
        static let hotkey             = "localvoice_hotkey"
        static let launchAtLogin      = "localvoice_launchAtLogin"
        static let showOverlay        = "localvoice_showRecordingOverlay"
        static let playSound          = "localvoice_playSoundOnToggle"
        static let sttEngine          = "localvoice_sttEngine"
        static let modelSource        = "localvoice_modelSource"
        static let textInjection      = "localvoice_textInjectionMethod"
        static let smartSpacing       = "localvoice_smartSpacing"
        static let language           = "localvoice_language"
        static let punctuation        = "localvoice_punctuation"
        static let enableRewriting    = "localvoice_enableTextRewriting"
    }

    var hotkey: HotkeyBinding {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.hotkey) else { return .fnKey }
            return HotkeyBinding(rawValue: raw) ?? .fnKey
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.hotkey) }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.object(forKey: Keys.launchAtLogin) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin) }
    }

    var showRecordingOverlay: Bool {
        get { UserDefaults.standard.object(forKey: Keys.showOverlay) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showOverlay) }
    }

    var playSoundOnToggle: Bool {
        get { UserDefaults.standard.object(forKey: Keys.playSound) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.playSound) }
    }

    var sttEngine: STTEngine {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.sttEngine) else { return .qwen3ASR06B6bit }
            return STTEngine(rawValue: raw) ?? .qwen3ASR06B6bit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.sttEngine) }
    }

    var modelSource: ModelSource {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.modelSource) else { return .huggingface }
            return ModelSource(rawValue: raw) ?? .huggingface
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.modelSource) }
    }

    var textInjectionMethod: TextInjectionMethod {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.textInjection) else { return .automatic }
            return TextInjectionMethod(rawValue: raw) ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.textInjection) }
    }

    var smartSpacing: Bool {
        get { UserDefaults.standard.object(forKey: Keys.smartSpacing) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.smartSpacing) }
    }

    var language: LanguagePreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.language) else { return .autoDetect }
            return LanguagePreference(rawValue: raw) ?? .autoDetect
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.language) }
    }

    var punctuation: PunctuationPreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.punctuation) else { return .smart }
            return PunctuationPreference(rawValue: raw) ?? .smart
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.punctuation) }
    }

    var enableTextRewriting: Bool {
        get { UserDefaults.standard.object(forKey: Keys.enableRewriting) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enableRewriting) }
    }
}

// MARK: - Hotkey

enum HotkeyBinding: String, CaseIterable, Identifiable {
    case fnKey = "Fn / Globe"
    case rightCommand = "Right Command"
    case leftOption = "Left Option"
    case custom = "Custom..."

    var id: String { rawValue }

    var keyCode: UInt32? {
        switch self {
        case .fnKey: return 0x3F
        case .rightCommand: return 0x36
        case .leftOption: return 0x3A
        case .custom: return nil
        }
    }

    var displayName: String {
        switch self {
        case .fnKey: return "Hold Fn to dictate"
        case .rightCommand: return "Hold Right Command to dictate"
        case .leftOption: return "Hold Left Option to dictate"
        case .custom: return "Press custom key to dictate"
        }
    }
}

// MARK: - Model Source

enum ModelSource: String, CaseIterable, Identifiable {
    case huggingface = "HuggingFace"
    case huggingfaceMirror = "HuggingFace Mirror (hf-mirror.com)"
    case modelscope = "ModelScope (魔搭)"

    var id: String { rawValue }

    var baseURL: String {
        switch self {
        case .huggingface: return "https://huggingface.co"
        case .huggingfaceMirror: return "https://hf-mirror.com"
        case .modelscope: return "https://modelscope.cn"
        }
    }

    var apiBaseURL: String {
        switch self {
        case .huggingface, .huggingfaceMirror:
            return "\(baseURL)/api/models"
        case .modelscope:
            return "\(baseURL)/api/v1/models"
        }
    }

    /// Download base URL for model files
    func resolveBaseURL(repoID: String) -> String {
        switch self {
        case .huggingface, .huggingfaceMirror:
            // https://huggingface.co/{repo_id}/resolve/main/{file}
            return "\(baseURL)/\(repoID)/resolve/main"
        case .modelscope:
            // https://modelscope.cn/models/{repo_id}/resolve/master/{file}
            return "\(baseURL)/models/\(repoID)/resolve/master"
        }
    }

    var displayName: String {
        switch self {
        case .huggingface: return "HuggingFace"
        case .huggingfaceMirror: return "HF Mirror"
        case .modelscope: return "魔搭"
        }
    }
}

// MARK: - STT Engine

enum STTEngine: String, CaseIterable, Identifiable {
    // 0.6B variants
    case qwen3ASR06B4bit  = "Qwen3-ASR 0.6B 4bit"
    case qwen3ASR06B5bit  = "Qwen3-ASR 0.6B 5bit"
    case qwen3ASR06B6bit  = "Qwen3-ASR 0.6B 6bit"
    case qwen3ASR06B8bit  = "Qwen3-ASR 0.6B 8bit"
    case qwen3ASR06BBf16  = "Qwen3-ASR 0.6B bf16"
    // 1.7B variants
    case qwen3ASR17B4bit  = "Qwen3-ASR 1.7B 4bit"
    case qwen3ASR17B5bit  = "Qwen3-ASR 1.7B 5bit"
    case qwen3ASR17B6bit  = "Qwen3-ASR 1.7B 6bit"
    case qwen3ASR17B8bit  = "Qwen3-ASR 1.7B 8bit"

    var id: String { rawValue }

    /// HuggingFace / HF Mirror repo ID
    var hfRepoID: String {
        switch self {
        case .qwen3ASR06B4bit: return "mlx-community/Qwen3-ASR-0.6B-4bit"
        case .qwen3ASR06B5bit: return "mlx-community/Qwen3-ASR-0.6B-5bit"
        case .qwen3ASR06B6bit: return "mlx-community/Qwen3-ASR-0.6B-6bit"
        case .qwen3ASR06B8bit: return "mlx-community/Qwen3-ASR-0.6B-8bit"
        case .qwen3ASR06BBf16: return "mlx-community/Qwen3-ASR-0.6B-bf16"
        case .qwen3ASR17B4bit: return "mlx-community/Qwen3-ASR-1.7B-4bit"
        case .qwen3ASR17B5bit: return "mlx-community/Qwen3-ASR-1.7B-5bit"
        case .qwen3ASR17B6bit: return "mlx-community/Qwen3-ASR-1.7B-6bit"
        case .qwen3ASR17B8bit: return "mlx-community/Qwen3-ASR-1.7B-8bit"
        }
    }

    /// ModelScope repo ID (same as HF)
    var modelscopeRepoID: String { hfRepoID }

    var displayName: String {
        switch self {
        case .qwen3ASR06B4bit: return "Qwen3-ASR 0.6B · 4-bit"
        case .qwen3ASR06B5bit: return "Qwen3-ASR 0.6B · 5-bit"
        case .qwen3ASR06B6bit: return "Qwen3-ASR 0.6B · 6-bit"
        case .qwen3ASR06B8bit: return "Qwen3-ASR 0.6B · 8-bit"
        case .qwen3ASR06BBf16: return "Qwen3-ASR 0.6B · bf16"
        case .qwen3ASR17B4bit: return "Qwen3-ASR 1.7B · 4-bit"
        case .qwen3ASR17B5bit: return "Qwen3-ASR 1.7B · 5-bit"
        case .qwen3ASR17B6bit: return "Qwen3-ASR 1.7B · 6-bit"
        case .qwen3ASR17B8bit: return "Qwen3-ASR 1.7B · 8-bit"
        }
    }

    /// Model family: 0.6B or 1.7B
    var is06B: Bool {
        switch self {
        case .qwen3ASR06B4bit, .qwen3ASR06B5bit, .qwen3ASR06B6bit,
             .qwen3ASR06B8bit, .qwen3ASR06BBf16:
            return true
        default:
            return false
        }
    }

    /// Approximate RAM usage at runtime
    var ramUsage: String {
        switch self {
        case .qwen3ASR06B4bit: return "~0.8 GB"
        case .qwen3ASR06B5bit: return "~1.0 GB"
        case .qwen3ASR06B6bit: return "~1.2 GB"
        case .qwen3ASR06B8bit: return "~1.5 GB"
        case .qwen3ASR06BBf16: return "~2.0 GB"
        case .qwen3ASR17B4bit: return "~1.8 GB"
        case .qwen3ASR17B5bit: return "~2.2 GB"
        case .qwen3ASR17B6bit: return "~2.6 GB"
        case .qwen3ASR17B8bit: return "~3.5 GB"
        }
    }

    /// Accuracy rating (1–5 stars)
    var accuracyRating: Int {
        switch self {
        case .qwen3ASR06B4bit: return 3
        case .qwen3ASR06B5bit: return 3
        case .qwen3ASR06B6bit: return 4
        case .qwen3ASR06B8bit: return 4
        case .qwen3ASR06BBf16: return 4
        case .qwen3ASR17B4bit: return 4
        case .qwen3ASR17B5bit: return 4
        case .qwen3ASR17B6bit: return 5
        case .qwen3ASR17B8bit: return 5
        }
    }

    /// Whether this is the recommended default choice
    var isRecommended: Bool { self == .qwen3ASR06B6bit }

    /// Expected model files (all variants share the same structure)
    var requiredFiles: [String] {
        return [
            "config.json",
            "tokenizer_config.json",
            "vocab.json",
            "merges.txt",
            "preprocessor_config.json",
            "model.safetensors",
        ]
    }

    /// Approximate total download size
    var downloadSize: String {
        switch self {
        case .qwen3ASR06B4bit: return "~580 MB"
        case .qwen3ASR06B5bit: return "~680 MB"
        case .qwen3ASR06B6bit: return "~790 MB"
        case .qwen3ASR06B8bit: return "~1.0 GB"
        case .qwen3ASR06BBf16: return "~1.6 GB"
        case .qwen3ASR17B4bit: return "~1.2 GB"
        case .qwen3ASR17B5bit: return "~1.5 GB"
        case .qwen3ASR17B6bit: return "~1.8 GB"
        case .qwen3ASR17B8bit: return "~2.4 GB"
        }
    }
}

// MARK: - Text Injection

enum TextInjectionMethod: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case clipboardOnly = "Clipboard Only"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .automatic: return "Uses Accessibility API with clipboard fallback"
        case .clipboardOnly: return "Copies to clipboard, user pastes manually"
        }
    }
}

// MARK: - Language

enum LanguagePreference: String, CaseIterable, Identifiable {
    case autoDetect = "Auto-detect"
    case chinese = "Chinese"
    case english = "English"

    var id: String { rawValue }
}

// MARK: - Punctuation

enum PunctuationPreference: String, CaseIterable, Identifiable {
    case smart = "Smart"
    case manualOnly = "Manual only"
    case none = "None"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .smart: return "Adds punctuation based on pauses"
        case .manualOnly: return "Only adds punctuation you speak"
        case .none: return "No punctuation added"
        }
    }
}

// MARK: - Permission State

struct PermissionState {
    var microphone: PermissionStatus = .unknown
    var accessibility: PermissionStatus = .unknown

    var allGranted: Bool {
        microphone == .granted && accessibility == .granted
    }

    var missingPermissions: [String] {
        var missing: [String] = []
        if microphone != .granted { missing.append("Microphone") }
        if accessibility != .granted { missing.append("Accessibility") }
        return missing
    }
}

enum PermissionStatus: Equatable {
    case unknown
    case granted
    case denied
    case restricted

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .unknown: return .white.opacity(Color.contentHintOpacity)
        case .granted: return .appSuccess
        case .denied: return .appError
        case .restricted: return .appWarning
        }
    }

    var statusText: String {
        switch self {
        case .unknown: return "Not checked"
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        }
    }
}

// MARK: - Model State

struct ModelState {
    /// Engines that have been fully downloaded
    var downloadedEngines: Set<String> = []

    /// Per-engine download phase
    var downloadPhases: [String: ModelDownloadPhase] = [:]

    /// Per-engine download progress (0.0 - 1.0)
    var downloadProgress: [String: Double] = [:]

    /// Per-file download progress for currently downloading engine
    var fileProgress: [String: [String: Double]] = [:]

    /// Current file being downloaded
    var currentFileName: String?

    /// Available disk space display string
    var availableDiskSpace: String = "Unknown"

    /// Last error per engine
    var downloadErrors: [String: String] = [:]

    // -- Live download stats (per engine) --

    /// Human-readable download speed, e.g. "2.3 MB/s"
    var downloadSpeed: [String: String] = [:]

    /// Downloaded bytes so far (across all files in this download session)
    var downloadedBytes: [String: Int64] = [:]

    /// Expected total bytes for the whole download
    var totalBytes: [String: Int64] = [:]

    /// Human-readable ETA, e.g. "~2 min"
    var downloadETA: [String: String] = [:]

    /// Whether a partial (resumable) download exists on disk
    var hasPartialDownload: [String: Bool] = [:]

    // MARK: - Helpers

    func isDownloaded(_ engine: STTEngine) -> Bool {
        downloadedEngines.contains(engine.rawValue)
    }

    func phase(for engine: STTEngine) -> ModelDownloadPhase {
        downloadPhases[engine.rawValue] ?? .idle
    }

    func progress(for engine: STTEngine) -> Double {
        downloadProgress[engine.rawValue] ?? 0
    }

    func speed(for engine: STTEngine) -> String {
        downloadSpeed[engine.rawValue] ?? ""
    }

    func eta(for engine: STTEngine) -> String {
        downloadETA[engine.rawValue] ?? ""
    }

    func bytesDownloaded(for engine: STTEngine) -> Int64 {
        downloadedBytes[engine.rawValue] ?? 0
    }

    func bytesTotal(for engine: STTEngine) -> Int64 {
        totalBytes[engine.rawValue] ?? 0
    }

    func hasPartial(for engine: STTEngine) -> Bool {
        hasPartialDownload[engine.rawValue] ?? false
    }

    mutating func resetDownloadState(for engine: STTEngine) {
        downloadPhases[engine.rawValue] = .idle
        downloadProgress[engine.rawValue] = 0
        fileProgress[engine.rawValue] = nil
        currentFileName = nil
        downloadErrors[engine.rawValue] = nil
        downloadSpeed[engine.rawValue] = nil
        downloadedBytes[engine.rawValue] = nil
        totalBytes[engine.rawValue] = nil
        downloadETA[engine.rawValue] = nil
    }
}

// MARK: - Model Download Phase

enum ModelDownloadPhase: Equatable {
    case idle
    case fetching    // querying repo file list
    case downloading // downloading files
    case verifying   // checking downloaded files
    case completed
    case retrying(Int, String)  // auto-retry attempt + last error
    case failed(String)

    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed: return false
        case .fetching, .downloading, .verifying, .retrying: return true
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Not downloaded"
        case .fetching: return "Fetching file list..."
        case .downloading: return "Downloading..."
        case .verifying: return "Verifying..."
        case .completed: return "Downloaded"
        case .retrying(let attempt, _): return "Retry \(attempt)/10..."
        case .failed(let error): return "Failed: \(error)"
        }
    }
}
