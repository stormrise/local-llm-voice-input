//
// HotkeyMonitor.swift
// LocalVoice
//
// Global Fn key monitoring via CGEventTap
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import CoreGraphics
import Carbon
import AppKit
import ApplicationServices
import Foundation

// MARK: - Hotkey Monitor

/// Listens for a global hotkey (Fn, Right Command, etc.) using CGEventTap.
///
/// CGEventTap is used (not NSEvent.addGlobalMonitorForEvents) because Fn/Globe key
/// generates low-level hardware events that NSEvent cannot capture.
///
/// Requires Accessibility permission (System Settings → Privacy → Accessibility).
/// Uses a stable self-signed certificate for consistent TCC tracking across rebuilds.
final class HotkeyMonitor: @unchecked Sendable {
    /// Called when the hotkey is pressed down (recording should start).
    var onKeyDown: (() -> Void)?

    /// Called when the hotkey is released (recording should stop).
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentKeyCode: UInt32?
    private var isKeyDownActive = false
    private var healthCheckTimer: Timer?

    /// Whether the event tap is currently running.
    private(set) var isMonitoring = false

    /// Start listening for the given key.
    func start(keyCode: UInt32) {
        guard !isMonitoring else { return }

        currentKeyCode = keyCode

        // Check Accessibility permission (required for CGEventTap)
        if !AXIsProcessTrusted() {
            AppLogger.shared.error("❌ Accessibility permission not granted — grant it in System Settings → Privacy → Accessibility → add LocalVoice, then relaunch")
            // Prompt the user via system dialog
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            return
        }

        // Fn/Globe key generates flagsChanged events, not keyDown/keyUp
        let eventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: HotkeyMonitor.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLogger.shared.error("❌ CGEventTap creation failed — Accessibility permission may not be active, try relaunching the app")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source = runLoopSource else {
            AppLogger.shared.error("❌ CFRunLoopSource creation failed")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isMonitoring = true
        startHealthCheck()
        AppLogger.shared.info("✅ Hotkey monitor started (CGEventTap, keyCode=0x\(String(format: "%02X", keyCode)))")
    }

    /// Stop listening.
    func stop() {
        stopHealthCheck()
        guard let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isMonitoring = false
        isKeyDownActive = false
        AppLogger.shared.info("⏹️ Hotkey monitor stopped")
    }

    /// Update the hotkey binding without restarting the tap.
    func updateKeyCode(_ keyCode: UInt32) {
        currentKeyCode = keyCode
        AppLogger.shared.info("🔄 Hotkey updated to keyCode=0x\(String(format: "%02X", keyCode))")
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        stopHealthCheck()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
    }

    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    /// Periodically verify the event tap is still enabled.
    /// The system can disable the tap if the app appears unresponsive.
    private func checkHealth() {
        guard let tap = eventTap, isMonitoring else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            AppLogger.shared.warn("⚠️ Event tap was disabled, re-enabling...")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Callback

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        monitor.handleEvent(type: type, event: event)
        return Unmanaged.passUnretained(event) // Pass event through — don't swallow it
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard let targetKey = currentKeyCode else { return }

        // Re-enable the tap if the system disabled it due to timeout.
        // This can happen when the main thread is blocked (e.g., slow I/O).
        if type == .tapDisabledByTimeout {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                AppLogger.shared.warn("⚠️ Event tap was disabled by timeout, re-enabled")
            }
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // FlagsChanged — modifier key state change
        if type == .flagsChanged {
            if targetKey == UInt32.fnKey {
                // Fn key: use maskSecondaryFn flag (more reliable than keycode 0x3F).
                // The Fn/Globe key on modern Mac keyboards reports state changes via
                // CGEventFlags.maskSecondaryFn rather than a unique keycode.
                let flags = event.flags
                let fnPressed = flags.contains(.maskSecondaryFn)

                if fnPressed {
                    if !isKeyDownActive {
                        isKeyDownActive = true
                        AppLogger.shared.info("🔑 Fn key DOWN (maskSecondaryFn)")
                        Task { @MainActor [weak self] in self?.onKeyDown?() }
                    }
                } else {
                    if isKeyDownActive {
                        isKeyDownActive = false
                        AppLogger.shared.info("🔑 Fn key UP (maskSecondaryFn cleared)")
                        Task { @MainActor [weak self] in self?.onKeyUp?() }
                    }
                }
            } else {
                // Other modifier keys: use keycode comparison (e.g., Caps Lock)
                if keyCode == targetKey {
                    if !isKeyDownActive {
                        isKeyDownActive = true
                        AppLogger.shared.info("🔑 Hotkey DOWN (flagsChanged) keyCode=0x\(String(format: "%02X", keyCode))")
                        Task { @MainActor [weak self] in self?.onKeyDown?() }
                    }
                } else {
                    // Any other modifier change while a modifier hotkey is held → keyUp
                    if isKeyDownActive {
                        isKeyDownActive = false
                        AppLogger.shared.info("🔑 Hotkey UP (flagsChanged) keyCode=0x\(String(format: "%02X", keyCode))")
                        Task { @MainActor [weak self] in self?.onKeyUp?() }
                    }
                }
            }
            return
        }

        // Standard keyDown/keyUp for non-modifier keys
        guard keyCode == targetKey else { return }

        switch type {
        case .keyDown:
            if !isKeyDownActive {
                isKeyDownActive = true
                AppLogger.shared.info("🔑 Hotkey DOWN (keyDown) keyCode=0x\(String(format: "%02X", keyCode))")
                Task { @MainActor [weak self] in self?.onKeyDown?() }
            }
        case .keyUp:
            isKeyDownActive = false
            AppLogger.shared.info("🔑 Hotkey UP (keyUp) keyCode=0x\(String(format: "%02X", keyCode))")
            Task { @MainActor [weak self] in self?.onKeyUp?() }
        default:
            break
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Keycode Constants

extension UInt32 {
    /// Fn / Globe key
    static let fnKey: UInt32 = 0x3F
    /// Right Command
    static let rightCommand: UInt32 = 0x36
    /// Left Option / Alt
    static let leftOption: UInt32 = 0x3A
    /// Right Option / Alt
    static let rightOption: UInt32 = 0x3D
    /// Left Command
    static let leftCommand: UInt32 = 0x37
    /// Caps Lock
    static let capsLock: UInt32 = 0x39
}
