//
// TextInjector.swift
// LocalVoice
//
// Text injection via clipboard + Cmd+V
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import ApplicationServices
import Cocoa

// MARK: - Text Injector

/// Injects transcribed text into the currently focused UI element.
///
/// Strategy: Clipboard + Cmd+V (universal fallback).
/// AXUIElement direct value writing was removed because it does not work reliably
/// with Electron/WebView apps (VS Code, Slack, etc.). Clipboard paste handles
/// both native macOS apps and Electron apps uniformly.
///
/// The `automatic` and `clipboardOnly` modes currently use the same underlying
/// clipboard path. `clipboardOnly` is retained as a user-visible option to avoid
/// any AX-based injection if it is added back in the future.
@MainActor
final class TextInjector {
    private let config: AppConfig
    private let pasteboard = NSPasteboard.general

    init(config: AppConfig = AppConfig.defaults) {
        self.config = config
    }

    /// Inject text: clipboard paste first (works everywhere), AX as fallback.
    @MainActor
    func inject(_ text: String, method: TextInjectionMethod) async throws {
        guard !text.isEmpty else { return }

        // Always trim aggressively
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        do {
            switch method {
            case .automatic:
                // Strategy A: Clipboard + Cmd+V (universal, works with Electron/native)
                try await injectViaClipboard(cleanText)

            case .clipboardOnly:
                try await injectViaClipboard(cleanText)
            }
            AppLogger.shared.info("✅ Text injected successfully")
        } catch {
            AppLogger.shared.error("❌ Text injection failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Clipboard Injection

    /// Save current clipboard → set new text → simulate Cmd+V → restore.
    private func injectViaClipboard(_ text: String) async throws {
        AppLogger.shared.info("📝 Injecting via clipboard")
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let savedPasteboardItems = savePasteboard()

        // Wait for physical modifier keys to be fully released
        // This prevents the simulated Cmd+V from conflicting with the user's actual key release
        try await waitForModifierRelease()

        // Clear pasteboard and wait briefly for it to take effect
        pasteboard.clearContents()
        try await Task.sleep(for: .milliseconds(config.textInjection.clipboardClearDelayMs))

        // Set text on pasteboard
        pasteboard.setString(cleanText, forType: .string)
        try await Task.sleep(for: .milliseconds(config.textInjection.clipboardSetDelayMs))

        // Simulate Cmd+V (Paste)
        try simulatePaste()

        // Wait for the target app to process the paste
        try await Task.sleep(for: .milliseconds(config.textInjection.pasteWaitDelayMs))

        // Restore original pasteboard
        restorePasteboard(savedPasteboardItems)
    }

    // MARK: - Pasteboard Save/Restore

    /// Save all pasteboard items with their types.
    func savePasteboard() -> [PasteboardItem] {
        var items: [PasteboardItem] = []
        for pbItem in pasteboard.pasteboardItems ?? [] {
            var types: [NSPasteboard.PasteboardType: Data] = [:]
            for type in pbItem.types {
                if let data = pbItem.data(forType: type) {
                    types[type] = data
                }
            }
            items.append(PasteboardItem(types: types))
        }
        return items
    }

    /// Restore saved pasteboard items.
    func restorePasteboard(_ items: [PasteboardItem]) {
        pasteboard.clearContents()
        for item in items {
            let pbItem = NSPasteboardItem()
            for (type, data) in item.types {
                pbItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([pbItem])
        }
    }

    // MARK: - Modifier Release Wait

    /// Poll until no modifier keys are physically held down (up to configured timeout).
    private func waitForModifierRelease() async throws {
        let maxWait = config.textInjection.modifierReleaseTimeoutSeconds
        let start = Date()

        while Date().timeIntervalSince(start) < maxWait {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // No command, option, control, or fn held
            if !flags.contains(.command) && !flags.contains(.option) && !flags.contains(.control) {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        // Timed out — proceed anyway
    }

    // MARK: - Simulate Cmd+V

    /// Post CGEvent for Cmd+V paste.
    private func simulatePaste() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TextInjectorError.eventSourceFailed
        }

        // Key down: V (keycode 9) with Cmd modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            throw TextInjectorError.eventCreationFailed
        }
        keyDown.flags = .maskCommand

        // Key up: V
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            throw TextInjectorError.eventCreationFailed
        }
        keyUp.flags = .maskCommand

        // Post events directly to the HID event stream
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }


}

// MARK: - Types

struct PasteboardItem {
    let types: [NSPasteboard.PasteboardType: Data]
}

// MARK: - Errors

enum TextInjectorError: LocalizedError {
    case eventSourceFailed
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventSourceFailed: return "Failed to create CGEventSource"
        case .eventCreationFailed: return "Failed to create keyboard events"
        }
    }
}
