//
// MenuBarView.swift
// LocalVoice
//
// Menu bar dropdown content
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {
    @Bindable var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status Header
            statusHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Last transcription snippet
            if let snippet = lastTranscriptionSnippet {
                transcriptionSnippet(snippet)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
            }

            // Hotkey Display
            hotkeyDisplay
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // Quick Actions
            quickActions
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Settings & Quit
            menuFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(state.menuBarState.tintColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: state.menuBarState.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(state.menuBarState.tintColor)
                    .symbolEffect(.pulse, isActive: state.menuBarState == .recording)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTextPrimary)

                Text(statusSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Pulsing dot for recording
            if state.menuBarState == .recording {
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 8, height: 8)
                    .shadow(color: .appPrimary.opacity(0.6), radius: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.menuBarState)
    }

    private var statusTitle: String {
        switch state.menuBarState {
        case .idle: return state.locale.menuReady
        case .recording: return state.locale.menuRecording
        case .transcribing: return state.locale.menuTranscribing
        case .error(let msg): return msg
        }
    }

    private var statusSubtitle: String {
        switch state.recordingState {
        case .recording(let info): return info.durationFormatted
        case .complete(let text): return String(text.prefix(40)) + (text.count > 40 ? "..." : "")
        case .failed: return state.locale.somethingWentWrong
        default: return state.locale.menuOffline
        }
    }

    private var lastTranscriptionSnippet: String? {
        if case .complete(let text) = state.recordingState, !text.isEmpty {
            return text
        }
        return nil
    }

    private func transcriptionSnippet(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.locale.isChinese ? "最近转录" : "Last transcription")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(3)
        }
    }

    // MARK: - Hotkey Display

    private var hotkeyDisplay: some View {
        VStack(spacing: 6) {
            // Hotkey
            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 16)

                Text(state.settings.hotkey.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                // Privacy badge
                HStack(spacing: 3) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 8))
                    Text("Local & offline")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Color.appSuccess)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appSuccess.opacity(0.1))
                .clipShape(Capsule())
            }

            // Model status
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 16)

                Text(state.settings.sttEngine.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                modelStatusBadge
            }
        }
    }

    @ViewBuilder
    private var modelStatusBadge: some View {
        if state.isModelLoading {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 10, height: 10)
                Text(state.locale.isChinese ? "加载中" : "Loading")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color.appWarning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appWarning.opacity(0.1))
            .clipShape(Capsule())
        } else if state.isModelLoaded {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                Text(state.locale.isChinese ? "已就绪" : "Ready")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color.appSuccess)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appSuccess.opacity(0.1))
            .clipShape(Capsule())
        } else {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 8))
                Text(state.locale.isChinese ? "未加载" : "Not loaded")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color.appTextSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appTextSecondary.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.permissions.microphone != .granted {
                menuItemButton(
                    icon: "mic.circle.fill",
                    title: state.locale.menuMicGrant,
                    color: Color.appPrimary
                ) {
                    openMicrophoneSettings()
                }
            }

            if state.permissions.accessibility != .granted {
                menuItemButton(
                    icon: "lock.open.fill",
                    title: state.locale.menuAccGrant,
                    color: Color.appWarning
                ) {
                    openAccessibilitySettings()
                }
            }

            // Show recording overlay toggle
            if state.settings.showRecordingOverlay {
                menuItemButton(
                    icon: "eye.fill",
                    title: state.locale.menuOverlayOn,
                    color: Color.appSuccess
                ) {
                    state.settings.showRecordingOverlay = false
                }
            } else {
                menuItemButton(
                    icon: "eye.slash.fill",
                    title: state.locale.menuOverlayOff,
                    color: .secondary
                ) {
                    state.settings.showRecordingOverlay = true
                }
            }
        }
    }

    // MARK: - Footer

    private var menuFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            menuItemButton(icon: "gearshape.fill", title: state.locale.settings, color: Color.appTextPrimary) {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()
                .padding(.vertical, 4)

            menuItemButton(icon: "power", title: state.locale.quitApp, color: .appError) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Helpers

    private func menuItemButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

// (MenuBarExtraContent moved to LocalVoiceApp.swift)
