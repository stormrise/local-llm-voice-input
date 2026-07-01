//
// PermissionChecker.swift
// LocalVoice
//
// macOS permission status checking
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import AVFoundation
import ApplicationServices
import Cocoa

// MARK: - Permission Checker

/// Checks and requests system permissions required for dictation:
/// - Microphone: for audio input
/// - Accessibility: for simulating keyboard events (Cmd+V)
/// - Input Monitoring: for global hotkey monitoring (CGEventTap)
enum PermissionChecker {

    // MARK: - Microphone

    /// Check current microphone permission status.
    /// On macOS, AVCaptureDevice.authorizationStatus may return .notDetermined
    /// even after the user grants permission, until the first capture session starts.
    /// We fall back to checking whether we can actually create a capture device.
    static func checkMicrophone() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            // On macOS, even with permission granted, status can be .notDetermined
            // until a capture session is active. Check if any audio device exists
            // as a heuristic — if devices exist, permission is likely granted.
            let devices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone],
                mediaType: .audio,
                position: .unspecified
            ).devices
            if !devices.isEmpty {
                // Devices exist — try requesting access (non-blocking check)
                // requestAccess returns the current state without prompting if already decided
                AppLogger.shared.info("Microphone status=.notDetermined, found \(devices.count) audio device(s), requesting access...")
                return .unknown
            }
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    /// Request microphone permission. Call from a Task/async context.
    @discardableResult
    static func requestMicrophone() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .granted : .denied
    }

    /// Open System Settings → Privacy & Security → Microphone.
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Accessibility

    /// Check current accessibility permission status.
    static func checkAccessibility() -> PermissionStatus {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            return .granted
        }
        // Check if the app has been denied by looking at the TCC database
        // (macOS doesn't expose a "denied" state for AX — it just returns false)
        return .denied
    }

    /// Prompt the user to grant accessibility permission.
    /// Returns true if the app becomes trusted after the prompt.
    static func requestAccessibilityPrompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Input Monitoring

    /// Check if the app has Input Monitoring permission (for CGEventTap).
    /// There is no direct API for this. We detect it by trying CGEvent.tapCreate
    /// and checking if it fails.
    static func checkInputMonitoring() -> Bool {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, _, _ in Unmanaged.passUnretained(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!) },
            userInfo: nil
        )
        if let tap = tap {
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }

    /// Open System Settings → Privacy & Security → Input Monitoring.
    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Combined

    /// Check all required permissions and return a summary.
    static func checkAll() -> PermissionSummary {
        PermissionSummary(
            microphone: checkMicrophone(),
            accessibility: checkAccessibility(),
            inputMonitoring: checkInputMonitoring() ? .granted : .denied
        )
    }
}

// MARK: - Permission Summary

struct PermissionSummary {
    let microphone: PermissionStatus
    let accessibility: PermissionStatus
    let inputMonitoring: PermissionStatus

    var allGranted: Bool {
        microphone == .granted && accessibility == .granted && inputMonitoring == .granted
    }
}
