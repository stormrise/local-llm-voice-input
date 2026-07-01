//
// RecordingOverlayView.swift
// LocalVoice
//
// Floating recording HUD overlay
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI
import AppKit

extension Notification.Name {
    static let overlayContentSizeChanged = Notification.Name("overlayContentSizeChanged")
}

// MARK: - Audio Waveform Bar

struct AudioWaveformBar: View {
    let delay: Double
    let maxHeight: CGFloat
    let color: Color

    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 2.5, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.35)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    height = maxHeight
                }
            }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let color: Color

    var body: some View {
        HStack(spacing: 2.5) {
            AudioWaveformBar(delay: 0.00, maxHeight: 10, color: color)
            AudioWaveformBar(delay: 0.08, maxHeight: 16, color: color)
            AudioWaveformBar(delay: 0.16, maxHeight: 12, color: color)
            AudioWaveformBar(delay: 0.24, maxHeight: 18, color: color)
            AudioWaveformBar(delay: 0.10, maxHeight: 14, color: color)
        }
    }
}

// MARK: - Recording Overlay Content (SwiftUI View)

struct RecordingOverlayContent: View {
    @Bindable var state: AppState
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.92
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            // Recording indicator dot
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 24, height: 24)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.appPrimary.opacity(0.6), radius: 6)
            }
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseScale)

            // Timer
            if case .recording(_) = state.recordingState {
                Text(elapsedFormatted)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }

            // Transcribing spinner
            if case .transcribing = state.recordingState {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }

            // Waveform
            if case .recording(_) = state.recordingState {
                AudioWaveformView(color: .appPrimary)
                    .frame(width: 32, height: 16)
                    .transition(.scale.combined(with: .opacity))
            }

            // Divider
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.appTextSecondary.opacity(0.2))
                .frame(width: 1, height: 16)

            // Partial transcription preview — always visible
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(state.partialTranscription.isEmpty ? (state.locale.isChinese ? "正在聆听..." : "Listening...") : state.partialTranscription)
                        .font(.system(size: 12))
                        .foregroundStyle(state.partialTranscription.isEmpty ? Color.appTextSecondary.opacity(0.5) : Color.appTextSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .id("partial")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: state.partialTranscription) { _, _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("partial", anchor: .trailing)
                    }
                    NotificationCenter.default.post(name: .overlayContentSizeChanged, object: nil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .hudGlassBackground(cornerRadius: 14)
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            pulseScale = 1.25
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
            if case .recording = state.recordingState {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: state.recordingState) { _, newState in
            switch newState {
            case .recording:
                startTimer()
            case .idle, .complete, .failed:
                stopTimer()
            default:
                break
            }
        }
    }

    private var statusColor: Color {
        switch state.recordingState {
        case .recording: return .appPrimary
        case .transcribing: return .appWarning
        case .failed: return .appError
        default: return .secondary
        }
    }

    private var statusLabel: String {
        switch state.recordingState {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .complete: return "Done"
        case .failed: return "Error"
        }
    }

    private var elapsedFormatted: String {
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startTimer() {
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                elapsed += 0.1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Overlay Controller (NSPanel)

/// Manages an NSPanel-based recording overlay that floats above all other windows,
/// works on all Spaces, and does not steal focus from the active app.
@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private var config: AppConfig = AppConfig.defaults
    private var resizeObserver: NSObjectProtocol?

    /// Show the overlay, creating the panel if needed.
    func show(state: AppState) {
        config = state.config
        if panel == nil {
            createPanel()
        }
        // Reposition near cursor on every show (cursor may have moved between sessions)
        repositionPanel()
        let content = RecordingOverlayContent(state: state)
        let hostingView = NSHostingView(rootView: content)
        panel?.contentView = hostingView
        resizePanelToFit()
        panel?.orderFrontRegardless()

        // Listen for content size changes (partial transcription growth)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: .overlayContentSizeChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resizePanelToFit()
            }
        }
    }

    /// Hide the overlay.
    func hide() {
        if let observer = resizeObserver {
            NotificationCenter.default.removeObserver(observer)
            resizeObserver = nil
        }
        panel?.contentView = nil
        panel?.orderOut(nil)
    }

    private func resizePanelToFit() {
        guard let panel, let hostingView = panel.contentView else { return }
        // Delay to let SwiftUI complete its layout pass before measuring
        DispatchQueue.main.async { [weak panel, weak hostingView] in
            guard let panel, let hostingView else { return }
            let fittingSize = hostingView.fittingSize
            let newHeight = max(44, fittingSize.height)
            guard panel.frame.height != newHeight else { return }
            var frame = panel.frame
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            panel.setFrame(frame, display: false)
        }
    }

    private func repositionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let frame = screen.visibleFrame
        var originX = mouseLocation.x - panelWidth / 2
        var originY = mouseLocation.y + config.recording.overlayOffsetFromCursorY
        originX = max(frame.minX, min(frame.maxX - panelWidth, originX))
        originY = max(frame.minY, min(frame.maxY - panelHeight, originY))
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: config.recording.overlayWidth, height: config.recording.overlayHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false

        self.panel = panel
    }
}
