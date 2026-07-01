//
// WelcomeView.swift
// LocalVoice
//
// Onboarding wizard (4 steps)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI

// MARK: - Welcome Step

enum WelcomeStep: Int {
    case intro = 0
    case permissions = 1
    case modelDownload = 2
    case ready = 3
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Bindable var state: AppState
    @State private var step: WelcomeStep = .intro
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Step indicators
            stepIndicators
                .padding(.top, 16)

            switch step {
            case .intro:
                introView
            case .permissions:
                permissionsSetupView
            case .modelDownload:
                modelDownloadView
            case .ready:
                readyView
            }
        }
        .frame(minWidth: 600, minHeight: 560)
        .background(
            LinearGradient(
                colors: [Color.appSurface.opacity(0.35), Color.appSurfaceVariant.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassBackground()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateIn = true
            }
        }
    }

    // MARK: - Step Indicators

    private var stepIndicators: some View {
        HStack(spacing: 0) {
            stepDot(.intro)
            stepLine(.intro)
            stepDot(.permissions)
            stepLine(.permissions)
            stepDot(.modelDownload)
            stepLine(.modelDownload)
            stepDot(.ready)
        }
    }

    private func stepDot(_ stepValue: WelcomeStep) -> some View {
        let isActive = stepValue == step
        let isCompleted = stepValue.rawValue < step.rawValue

        return Circle()
            .fill(isActive ? Color.appPrimary : (isCompleted ? Color.appSuccess : Color.secondary.opacity(0.2)))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.appPrimary.opacity(0.3) : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: step)
    }

    private func stepLine(_ beforeStep: WelcomeStep) -> some View {
        let isCompleted = beforeStep.rawValue < step.rawValue
        return Rectangle()
            .fill(isCompleted ? Color.appSuccess.opacity(0.4) : Color.secondary.opacity(0.12))
            .frame(width: 32, height: 2)
            .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary.opacity(0.2), Color.appPrimaryDark.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.appPrimary.opacity(0.35), radius: 24, x: 0, y: 8)
            }
            .scaleEffect(animateIn ? 1 : 0.6)
            .opacity(animateIn ? 1 : 0)

            // Title
            VStack(spacing: 8) {
                Text(state.locale.welcomeTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)

                Text(state.locale.welcomeSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)
            }

            // Feature bullets
            VStack(alignment: .leading, spacing: 14) {
                featureBullet(icon: "mic.fill", text: state.locale.welcomeFeature1)
                featureBullet(icon: "cpu.fill", text: state.locale.welcomeFeature2)
                featureBullet(icon: "lock.shield.fill", text: state.locale.welcomeFeature3)
            }
            .padding(.horizontal, 48)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 16)

            Spacer()

            // Get Started Button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .permissions
                }
            } label: {
                Text(state.locale.getStarted)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 220, height: 46)
                    .background(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.appPrimary.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)

            Spacer()
        }
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
                ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appPrimary)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    // MARK: - Permissions Setup View

    private var permissionsSetupView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text(state.locale.setupPermissions)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(state.locale.setupPermissionsDesc)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 28)

            // Permission Cards
            VStack(spacing: 12) {
                PermissionSetupCard(
                    icon: "mic.fill",
                    title: state.locale.microphone,
                    description: state.locale.microphoneDesc,
                    isGranted: state.permissions.microphone == .granted,
                    action: {
                        openMicrophoneSettings()
                    }
                )

                PermissionSetupCard(
                    icon: "lock.open.fill",
                    title: state.locale.accessibility,
                    description: state.locale.accessibilityDesc,
                    isGranted: state.permissions.accessibility == .granted,
                    action: {
                        openAccessibilitySettings()
                    }
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .intro
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text(state.locale.back)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(state.locale.skipForNow) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .modelDownload
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .modelDownload
                    }
                } label: {
                    Text(state.permissions.allGranted ? state.locale.continue : state.locale.setLater)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appOnPrimary)
                        .frame(width: 160, height: 40)
                        .background(
                            state.permissions.allGranted
                                ? AnyShapeStyle(LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(.secondary)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Model Download View

    private var modelDownloadView: some View {
        let hasAnyDownloaded = STTEngine.allCases.contains { state.models.isDownloaded($0) }

        return VStack(spacing: 12) {
            Spacer()

            // Header
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .padding(.bottom, 2)

                Text(state.locale.downloadModel)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(state.locale.downloadModelDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            // Model List (scrollable, capped height)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    ForEach(STTEngine.allCases) { engine in
                        WelcomeModelRow(engine: engine, state: state)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 260)

            // Download Source
            HStack(spacing: 8) {
                Text(state.locale.downloadSource)
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $state.settings.modelSource) {
                    ForEach(ModelSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.menu)
                Text(state.locale.downloadSourceDesc(state.settings.modelSource))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.appTextHint)
                Spacer()
            }
            .padding(.horizontal, 44)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .permissions
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text(state.locale.back)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                if !hasAnyDownloaded {
                    Button(state.locale.setLater) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .ready
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                }

                if hasAnyDownloaded {
                    Button {
                        let preferred = STTEngine.allCases.reversed().first { state.models.isDownloaded($0) }
                        if let engine = preferred {
                            state.settings.sttEngine = engine
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .ready
                        }
                    } label: {
                        Text(state.locale.continue)
                            .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appOnPrimary)
                        .frame(width: 160, height: 40)
                        .background(
                            LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func startDownload(engine: STTEngine) {
        state.modelDownloadService?.startDownload(
            engine: engine,
            source: state.settings.modelSource
        )
    }

    private func clearDownload(engine: STTEngine) {
        guard let service = state.modelDownloadService else { return }
        do {
            try service.deleteModel(engine: engine)
            state.models.downloadedEngines.remove(engine.rawValue)
            state.models.resetDownloadState(for: engine)
        } catch {
            state.models.downloadPhases[engine.rawValue] = .failed("Clear failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appSuccess.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.appSuccess)
                    .shadow(color: Color.appSuccess.opacity(0.3), radius: 16)
            }

            VStack(spacing: 8) {
                Text(state.locale.allSet)
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text(state.locale.allSetDesc)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
            }

            // Hotkey guidance card
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appPrimary)
                    Text(state.locale.isChinese ? "快捷键" : "Hotkey")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(state.settings.hotkey.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary.opacity(0.4))
                    )

                Text(state.locale.hotkeyRecordingDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .glassBackground(cornerRadius: 12)
            .padding(.horizontal, 60)

            // Quick tip
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text(state.locale.quickTip)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                }

                Text(state.locale.quickTipDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(16)
            .glassBackground(cornerRadius: 12)
            .padding(.horizontal, 60)

            Spacer()

            Button {
                state.completeOnboarding()
            } label: {
                Text(state.locale.startUsing)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 240, height: 46)
                    .background(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.appPrimary.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func openMicrophoneSettings() {
        Task {
            let result = await PermissionChecker.requestMicrophone()
            state.permissions.microphone = result
            if result != .granted {
                PermissionChecker.openMicrophoneSettings()
            }
        }
    }

    private func openAccessibilitySettings() {
        let prompted = PermissionChecker.requestAccessibilityPrompt()
        state.permissions.accessibility = PermissionChecker.checkAccessibility()
        if !prompted || state.permissions.accessibility != .granted {
            PermissionChecker.openAccessibilitySettings()
        }
    }
}

// MARK: - Welcome Model Row

struct WelcomeModelRow: View {
    let engine: STTEngine
    @Bindable var state: AppState

    private var phase: ModelDownloadPhase { state.models.phase(for: engine) }

    var body: some View {
        VStack(spacing: 6) {
            // Main row
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(engine.isRecommended ? Color.appPrimary.opacity(0.1) : Color.secondary.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: engine.isRecommended ? "star.bubble.fill" : "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(engine.isRecommended ? Color.appPrimary : Color.appWarning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(engine.displayName)
                            .font(.system(size: 12, weight: .semibold))
                        if engine.isRecommended {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                Text("Recommended")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(Color.appOnPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Label(engine.ramUsage, systemImage: "memorychip")
                            .font(.system(size: 9))
                        Label(engine.downloadSize, systemImage: "arrow.down.circle")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.appTextSecondary)
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

            // Downloaded indicator
            if state.models.isDownloaded(engine) && !phase.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appSuccess)
                        .font(.system(size: 9))
                    Text("Downloaded")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.appSuccess)
                    Spacer()
                }
            }
        }
        .padding(10)
        .glassBackground(cornerRadius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    engine.isRecommended
                        ? Color.appPrimary.opacity(0.2)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if phase.isActive {
            Button("Cancel") {
                cancelDownload()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.appWarning)
        } else if state.models.isDownloaded(engine) {
            Button("Delete") {
                deleteModel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.appError)
        } else if state.models.hasPartial(for: engine) {
            HStack(spacing: 4) {
                Button("Clear") {
                    deleteModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.appError)

                Button("Resume") {
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appPrimary)
            }
        } else {
            Button("Download") {
                startDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text(state.locale.modelStatusText(phase))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("\(Int(state.models.progress(for: engine) * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            ProgressView(value: state.models.progress(for: engine))
                .progressViewStyle(.linear)
                .tint(Color.appPrimary)

            HStack(spacing: 10) {
                if let speed = state.models.speed(for: engine) as String?, !speed.isEmpty {
                    Label(speed, systemImage: "speedometer")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }
                let downloaded = state.models.bytesDownloaded(for: engine)
                let total = state.models.bytesTotal(for: engine)
                if total > 0 {
                    Label(formatBytes(downloaded) + " / " + formatBytes(total), systemImage: "arrow.down.to.line")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }
                Spacer()
                if let eta = state.models.eta(for: engine) as String?, !eta.isEmpty {
                    Label(eta, systemImage: "clock")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.appTextHint)
                }
            }
        }
        .padding(8)
        .glassBackground(cornerRadius: 8)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.appWarning)
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.appWarning)
                    .lineLimit(2)
                Spacer()
                Button("Retry") {
                    startDownload()
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.appPrimary)
            }
            if state.models.hasPartial(for: engine) {
                Text("Partial download available — Retry will resume")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.appTextHint)
            }
        }
        .padding(6)
        .background(Color.appWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Actions

    private func startDownload() {
        state.modelDownloadService?.startDownload(engine: engine, source: state.settings.modelSource)
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

// MARK: - Permission Setup Card

struct PermissionSetupCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isGranted ? Color.appSuccess.opacity(0.1) : Color.appPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isGranted ? Color.appSuccess : Color.appPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.appSuccess)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appPrimary)
            }
        }
        .padding(14)
        .glassBackground(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.appSuccess.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }
}
