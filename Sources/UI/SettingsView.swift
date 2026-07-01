//
// SettingsView.swift
// LocalVoice
//
// Settings window with tabs (General, Model, Text, Permissions)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            tabSelector
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            // Tab Content
            tabContent
                .padding(20)
                .frame(minWidth: 520, minHeight: 380)
        }
        .background(
            LinearGradient(
                colors: [Color.appSurface.opacity(0.35), Color.appSurfaceVariant.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassBackground()
        .onAppear {
            checkPermissions()
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .white : Color.appTextPrimary)
                        Text(tabTitle(for: tab))
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .white : Color.appTextPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        selectedTab == tab
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.85), Color.appPrimaryDark.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                selectedTab == tab ? Color.appOnPrimary.opacity(0.2) : Color.appCardBorder,
                                lineWidth: selectedTab == tab ? 1 : 0.5
                            )
                    )
                    .shadow(
                        color: selectedTab == tab ? Color.appPrimary.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 3
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appCardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            GeneralTab(state: state)
        case .model:
            ModelTab(state: state)
        case .textInput:
            TextInputTab(state: state)
        case .permissions:
            PermissionsTab(state: state)
        case .donate:
            DonateTab()
        }
    }

    private func checkPermissions() {
        state.permissions.microphone = PermissionChecker.checkMicrophone()
        state.permissions.accessibility = PermissionChecker.checkAccessibility()
    }

    private func tabTitle(for tab: SettingsTab) -> String {
        switch tab {
        case .general: return state.locale.settingsGeneral
        case .model: return state.locale.settingsModel
        case .textInput: return state.locale.settingsText
        case .permissions: return state.locale.settingsPermissions
        case .donate: return state.locale.settingsDonate
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: CaseIterable, Identifiable {
    case general
    case model
    case textInput
    case permissions
    case donate

    var id: String { "\(self)" }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .model: return "cpu"
        case .textInput: return "text.cursor"
        case .permissions: return "lock.shield"
        case .donate: return "heart.fill"
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @Bindable var state: AppState
    @State private var showLogCleared = false
    @State private var showRecordingsCleared = false
    @Bindable private var themeManager = ThemeManager.shared

    var body: some View {
        let locale = Bindable(state.locale)

        Form {
            // Language
            Section {
                Picker(state.locale.languageLabel, selection: locale.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                Text(state.locale.languageDesc)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
            } header: {
                Label(state.locale.languageLabel, systemImage: "globe")
            }

            // Appearance / Theme
            Section {
                Picker(state.locale.theme, selection: $themeManager.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label(state.locale.appearance, systemImage: "paintpalette")
            }

            // Activation
            Section {
                Picker(state.locale.hotkey, selection: $state.settings.hotkey) {
                    ForEach(HotkeyBinding.allCases) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .pickerStyle(.menu)

                if state.settings.hotkey == .fnKey {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appPrimary)
                        Text(state.locale.hotkeyRecordingDesc)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.leading, 8)
                }
            } header: {
                Label(state.locale.hotkey, systemImage: "keyboard")
            }

            // Setup Guide
            Section {
                HStack {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(Color.appPrimary)
                    Text(state.locale.setupGuideSectionTitle)
                        .font(.system(size: 12))
                    Spacer()
                    Button(state.locale.openGuide) {
                        state.resetOnboarding()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            } header: {
                Label(state.locale.setupGuideSectionTitle, systemImage: "questionmark.circle")
            }

            // Behavior
            Section {
                Toggle(state.locale.launchAtLogin, isOn: $state.settings.launchAtLogin)
                Toggle(state.locale.recordingOverlay, isOn: $state.settings.showRecordingOverlay)
                Toggle(state.locale.playSound, isOn: $state.settings.playSoundOnToggle)
            } header: {
                Label(state.locale.behavior, systemImage: "switch.2")
            }

            // AI Rewriting
            Section {
                Toggle(state.locale.aiRewriting, isOn: $state.settings.enableTextRewriting)

                if state.settings.enableTextRewriting {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appPrimary)
                        Text(state.locale.aiRewritingDesc)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.leading, 8)
                }
            } header: {
                Label(state.locale.aiRewriting, systemImage: "wand.and.stars")
            }

            // Speech Language Preference
            Section {
                Picker(state.locale.languagePref, selection: $state.settings.language) {
                    ForEach(LanguagePreference.allCases) { lang in
                        Text(state.locale.languageName(lang)).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                if state.settings.language == .autoDetect {
                    Text(state.locale.autoDetectDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.leading, 8)
                }
            } header: {
                Label(state.locale.languagePref, systemImage: "character.bubble")
            }

            // Debug
            Section {
                HStack {
                    Image(systemName: "ant.fill")
                        .foregroundStyle(Color.appWarning)
                    Text(state.locale.debugLog)
                        .font(.system(size: 12))
                    Spacer()
                    Button(state.locale.viewLog) {
                        let logURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("com.vocaltype.app/debug.log")
                        NSWorkspace.shared.open(logURL)
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)

                    Button(showLogCleared ? state.locale.cleared : state.locale.clear) {
                        AppLogger.shared.clear()
                        showLogCleared = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            await MainActor.run { showLogCleared = false }
                        }
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .foregroundStyle(showLogCleared ? Color.appSuccess : Color.appWarning)

                    Button(showRecordingsCleared ? state.locale.cleared : state.locale.clearRecordings) {
                        clearDebugRecordings()
                        showRecordingsCleared = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showRecordingsCleared = false
                        }
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .foregroundStyle(showRecordingsCleared ? Color.appSuccess : Color.appWarning)
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextSecondary)
                    Text(state.locale.logsLocation)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.leading, 4)
            } header: {
                Label(state.locale.debug, systemImage: "ladybug")
            }
        }
        .formStyle(.grouped)
    }

    private func clearDebugRecordings() {
        let debugDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.vocaltype.app/debug_recordings")
        try? FileManager.default.removeItem(at: debugDir)
        AppLogger.shared.info("🧹 Cleared debug recordings")
    }
}

// MARK: - Model Tab

struct ModelTab: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            // Active Model
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(state.locale.activeModel, selection: $state.settings.sttEngine) {
                        Section("0.6B — " + (state.locale.isChinese ? "轻量快速" : "Light & Fast")) {
                            ForEach(STTEngine.allCases.filter(\.is06B)) { engine in
                                HStack {
                                    Text(engine.displayName)
                                    if engine.isRecommended {
                                        Text("(\(state.locale.recommended))")
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                }
                                .tag(engine)
                            }
                        }
                        Section("1.7B — " + (state.locale.isChinese ? "高精度" : "High Accuracy")) {
                            ForEach(STTEngine.allCases.filter { !$0.is06B }) { engine in
                                Text(engine.displayName).tag(engine)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: state.settings.sttEngine) { _, newEngine in
                        state.switchModel(to: newEngine)
                    }

                    if state.isModelLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(state.locale.loadingModel)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.leading, 4)
                    } else if state.isModelLoaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.appSuccess)
                            Text(state.locale.modelReady)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appSuccess)
                        }
                        .padding(.leading, 4)
                    }
                }
            } header: {
                Label(state.locale.activeModel, systemImage: "cpu")
            }

            // Download Source
            Section {
                Picker(state.locale.downloadSource, selection: $state.settings.modelSource) {
                    ForEach(ModelSource.allCases) { source in
                        HStack(spacing: 6) {
                            Text(source.rawValue)
                        }
                        .tag(source)
                    }
                }
                .pickerStyle(.menu)

                Text(state.locale.downloadSourceDesc(state.settings.modelSource))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.leading, 8)
            } header: {
                Label(state.locale.downloadSource, systemImage: "network")
            }

            // Model List
            Section {
                VStack(spacing: 0) {
                    // 0.6B family
                    HStack {
                        Text(state.locale.isChinese ? "0.6B · 轻量快速" : "0.6B · Light & Fast")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 6)

                    ForEach(STTEngine.allCases.filter(\.is06B)) { engine in
                        ModelRow(engine: engine, state: state)
                        if engine != STTEngine.allCases.filter(\.is06B).last {
                            Divider().padding(.leading, 8)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    // 1.7B family
                    HStack {
                        Text(state.locale.isChinese ? "1.7B · 高精度" : "1.7B · High Accuracy")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 6)

                    ForEach(STTEngine.allCases.filter { !$0.is06B }) { engine in
                        ModelRow(engine: engine, state: state)
                        if engine != STTEngine.allCases.filter({ !$0.is06B }).last {
                            Divider().padding(.leading, 8)
                        }
                    }
                }
            } header: {
                Label(state.locale.speechToTextEngine, systemImage: "waveform")
            }

            // Disk space
            Section {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.appTextSecondary)
                    Text(state.locale.availableDisk)
                    Spacer()
                    Text(state.models.availableDiskSpace)
                        .foregroundStyle(Color.appTextSecondary)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let engine: STTEngine
    @Bindable var state: AppState

    private var phase: ModelDownloadPhase { state.models.phase(for: engine) }

    var body: some View {
        VStack(spacing: 10) {
            // Main row
            HStack(alignment: .top, spacing: 12) {
                // Model info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(state.locale.modelDisplayName(engine))
                            .font(.system(size: 13, weight: .semibold))

                        if engine.isRecommended {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text(state.locale.recommended)
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color.appOnPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                        } else {
                            Text(state.locale.fastAndLight)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.appWarning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appWarning.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        Label(engine.ramUsage, systemImage: "memorychip")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)

                        Label(engine.downloadSize, systemImage: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)

                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < engine.accuracyRating ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundStyle(index < engine.accuracyRating ? .yellow : .secondary.opacity(0.3))
                            }
                            Text(state.locale.accuracy)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }

                    Text(state.locale.modelDescription(engine))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.top, 2)
                }

                Spacer()

                // Action button
                actionButton
            }

            // Progress section (only during active download)
            if phase.isActive {
                progressSection
            }

            // Error message
            if case .failed(let error) = phase {
                errorSection(error)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    engine == state.settings.sttEngine
                    ? AnyShapeStyle(LinearGradient(colors: [Color.appPrimary.opacity(0.5), Color.appPrimaryDark.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.appCardBorder),
                    lineWidth: engine == state.settings.sttEngine ? 1.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if phase.isActive {
            Button(state.locale.cancel) {
                cancelDownload()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.appWarning)
        } else if state.models.isDownloaded(engine) {
            Button(state.locale.delete) {
                deleteModel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.appError)
        } else if state.models.hasPartial(for: engine) {
            HStack(spacing: 6) {
                Button(state.locale.clear) {
                    deleteModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.appError)

                Button(state.locale.resume) {
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appPrimary)
            }
        } else {
            Button(state.locale.download) {
                startDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Phase + percentage
            HStack {
                Text(state.locale.modelStatusText(phase))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Text("\(Int(state.models.progress(for: engine) * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.appTextPrimary)
            }

            // Progress bar
            ProgressView(value: state.models.progress(for: engine))
                .progressViewStyle(.linear)
                .tint(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Stats row: speed | downloaded/total | ETA
            HStack(spacing: 12) {
                // Speed
                if let speed = state.models.speed(for: engine) as String?, !speed.isEmpty {
                    Label(speed, systemImage: "speedometer")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }

                // Downloaded / Total
                let downloaded = state.models.bytesDownloaded(for: engine)
                let total = state.models.bytesTotal(for: engine)
                if total > 0 {
                    Label(formatBytes(downloaded) + " / " + formatBytes(total), systemImage: "arrow.down.to.line")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }

                Spacer()

                // ETA
                if let eta = state.models.eta(for: engine) as String?, !eta.isEmpty {
                    Label(eta, systemImage: "clock")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }
            }

            // Current file name
            if let fileName = state.models.currentFileName {
                HStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.appTextHint)
                    Text(fileName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appWarning)

                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appWarning)
                    .lineLimit(2)

                Spacer()

                Button(state.locale.retry) {
                    startDownload()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.appPrimary)
            }

            // Show resume hint if partial files exist
            if state.models.hasPartial(for: engine) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 9))
                    Text(state.locale.partialDownloadHint)
                        .font(.system(size: 9))
                    Spacer()
                }
                .foregroundStyle(Color.appTextHint)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appWarning.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appWarning.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Actions

    private func startDownload() {
        guard let service = state.modelDownloadService else { return }
        let source = state.settings.modelSource
        service.startDownload(engine: engine, source: source)
        // Poll for completion after a reasonable delay
        Task {
            // Give the download a moment to start, then check periodically
            try? await Task.sleep(for: .seconds(1))
            // The download service updates the state as it progresses,
            // so we just kick it off and let the observable state update the UI
        }
    }

    private func cancelDownload() {
        state.modelDownloadService?.cancel(engine: engine)
        state.models.resetDownloadState(for: engine)
    }

    private func deleteModel() {
        guard let service = state.modelDownloadService else { return }
        do {
            try service.deleteModel(engine: engine)
            state.models.downloadedEngines.remove(engine.rawValue)
            state.models.resetDownloadState(for: engine)
        } catch {
            state.models.downloadPhases[engine.rawValue] = .failed("Delete failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Text Input Tab

struct TextInputTab: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section {
                Picker(state.locale.textInjection, selection: $state.settings.textInjectionMethod) {
                    ForEach(TextInjectionMethod.allCases) { method in
                        Text(state.locale.textInjectionMethodDescription(method)).tag(method)
                    }
                }
                .pickerStyle(.menu)

                Text(state.locale.textInjectionMethodDescription(state.settings.textInjectionMethod))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.leading, 8)
            } header: {
                Label(state.locale.textInjection, systemImage: "arrow.right.doc.on.clipboard")
            }

            Section {
                Toggle(state.locale.smartSpacing, isOn: $state.settings.smartSpacing)
            } header: {
                Label(state.locale.smartSpacing, systemImage: "text.insert")
            }

            Section {
                Picker(state.locale.languagePref, selection: $state.settings.language) {
                    ForEach(LanguagePreference.allCases) { lang in
                        Text(state.locale.languageName(lang)).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                if state.settings.language == .autoDetect {
                    Text(state.locale.autoDetectDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.leading, 8)
                }
            } header: {
                Label(state.locale.languagePref, systemImage: "globe")
            }

            Section {
                Picker(state.locale.punctuation, selection: $state.settings.punctuation) {
                    ForEach(PunctuationPreference.allCases) { punct in
                        Text(state.locale.punctuationDescription(punct)).tag(punct)
                    }
                }
                .pickerStyle(.menu)

                Text(state.locale.punctuationDescription(state.settings.punctuation))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.leading, 8)
            } header: {
                Label(state.locale.punctuation, systemImage: "text.bubble")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    icon: "mic.fill",
                    title: state.locale.microphone,
                    description: state.locale.microphoneAccessDesc,
                    status: state.permissions.microphone,
                    statusText: state.locale.permissionStatusText(state.permissions.microphone),
                    buttonText: state.locale.openSystemSettings,
                    action: openMicrophoneSettings
                )

                PermissionRow(
                    icon: "lock.open.fill",
                    title: state.locale.accessibility,
                    description: state.locale.accessibilityAccessDesc,
                    status: state.permissions.accessibility,
                    statusText: state.locale.permissionStatusText(state.permissions.accessibility),
                    buttonText: state.locale.openSystemSettings,
                    action: openAccessibilitySettings
                )
            } header: {
                Label(state.locale.systemPermissions, systemImage: "lock.shield")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.appPrimary)
                        Text(state.locale.whyPermissions)
                            .font(.system(size: 12, weight: .medium))
                    }

                    Text(state.locale.privacyDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            state.permissions.microphone = PermissionChecker.checkMicrophone()
            state.permissions.accessibility = PermissionChecker.checkAccessibility()
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let statusText: String
    let buttonText: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: status == .granted ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(status.iconColor)

                    if status != .granted {
                        Button(buttonText) {
                            action()
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// (PermissionChecker moved to PermissionChecker.swift)

// MARK: - Donate Tab

struct DonateTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("如果 LocalVoice 对你有帮助，可以请作者喝杯咖啡 ☕")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text("If LocalVoice helps you, buy the author a coffee ☕")
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            if let image = Self.loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                Text("收款码加载失败")
                    .foregroundStyle(Color.appTextHint)
            }

            Spacer()
        }
    }

    private static func loadImage() -> NSImage? {
        // Try Bundle.main first (built app)
        if let url = Bundle.main.url(forResource: "alipay_donate", withExtension: "jpg") {
            AppLogger.shared.info("📷 Found in Bundle.main: \(url.path)")
            if let img = NSImage(contentsOf: url) { return img }
        }
        // Try the SwiftPM resource bundle inside the app's Resources/
        if let mainURL = Bundle.main.bundleURL as URL? {
            let resourceBundleURL = mainURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent("LocalVoice_LocalVoice.bundle")
            AppLogger.shared.info("📷 Trying resource bundle: \(resourceBundleURL.path)")
            if let resourceBundle = Bundle(url: resourceBundleURL) {
                if let url = resourceBundle.url(forResource: "alipay_donate", withExtension: "jpg") {
                    AppLogger.shared.info("📷 Found in resource bundle: \(url.path)")
                    if let img = NSImage(contentsOf: url) { return img }
                }
            }
        }
        // Try all loaded bundles
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "alipay_donate", withExtension: "jpg") {
                AppLogger.shared.info("📷 Found in bundle: \(bundle.bundlePath)")
                if let img = NSImage(contentsOf: url) { return img }
            }
        }
        AppLogger.shared.info("📷 alipay_donate.jpg not found in any bundle")
        return nil
    }
}
