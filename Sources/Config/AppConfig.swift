//
// AppConfig.swift
// LocalVoice
//
// JSON-based app configuration with defaults
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

/// App-wide configuration loaded from JSON, with hardcoded defaults as fallback.
struct AppConfig: Codable {
    static let currentVersion = 2
    var configVersion: Int?
    var onboarding: OnboardingConfig
    var vad: VADConfig
    var partialTranscription: PartialTranscriptionConfig
    var recording: RecordingConfig
    var textInjection: TextInjectionConfig
    var model: ModelConfig

    struct OnboardingConfig: Codable {
        var hasCompletedSetup: Bool
    }

    struct VADConfig: Codable {
        var silenceThreshold: Float
        var silenceDurationSeconds: TimeInterval
        var checkIntervalSeconds: TimeInterval
        var windowSamplesForRMS: Int
    }

    struct PartialTranscriptionConfig: Codable {
        var enabled: Bool
        var intervalSeconds: TimeInterval
        var minSamplesForPartial: Int
        var maxSamplesCapped: Int
    }

    struct RecordingConfig: Codable {
        var sampleRate: Double
        var overlayOffsetFromCursorY: CGFloat
        var overlayWidth: CGFloat
        var overlayHeight: CGFloat
    }

    struct TextInjectionConfig: Codable {
        var clipboardClearDelayMs: Int
        var clipboardSetDelayMs: Int
        var pasteWaitDelayMs: Int
        var modifierReleaseTimeoutSeconds: TimeInterval
    }

    struct ModelConfig: Codable {
        var defaultTemperature: Float
        var defaultMaxTokens: Int
        var warmupDurationSeconds: TimeInterval
        var warmupTemperature: Float
    }

    /// Load config from bundle, then check for user override at
    /// ~/Library/Application Support/com.vocaltype.app/config.json.
    /// Hardcoded defaults are used if neither file exists.
    static func load() -> AppConfig {
        // 1. Try bundle config
        let bundleURL = Bundle.main.url(forResource: "default_config", withExtension: "json")
        if let url = bundleURL, let data = try? Data(contentsOf: url),
           let bundleConfig = try? JSONDecoder().decode(AppConfig.self, from: data) {
            // 2. Check for user override file — only use if version is current
            let userConfigURL = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/com.vocaltype.app/config.json")
            if let userData = try? Data(contentsOf: userConfigURL),
               let userConfig = try? JSONDecoder().decode(AppConfig.self, from: userData),
               (userConfig.configVersion ?? 0) >= AppConfig.currentVersion {
                return userConfig
            }
            return bundleConfig
        }

        // 3. Check user override even without bundle config
        let userConfigURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.vocaltype.app/config.json")
        if let userData = try? Data(contentsOf: userConfigURL),
           let userConfig = try? JSONDecoder().decode(AppConfig.self, from: userData),
           (userConfig.configVersion ?? 0) >= AppConfig.currentVersion {
            return userConfig
        }

        // 4. Fallback to hardcoded defaults
        return AppConfig.defaults
    }

    /// Hardcoded defaults matching default_config.json
    static let defaults = AppConfig(
        configVersion: currentVersion,
        onboarding: OnboardingConfig(hasCompletedSetup: false),
        vad: VADConfig(silenceThreshold: 0.05, silenceDurationSeconds: 4.0, checkIntervalSeconds: 0.3, windowSamplesForRMS: 4800),
        partialTranscription: PartialTranscriptionConfig(enabled: true, intervalSeconds: 0.5, minSamplesForPartial: 8000, maxSamplesCapped: 320000),
        recording: RecordingConfig(sampleRate: 16000, overlayOffsetFromCursorY: 40, overlayWidth: 380, overlayHeight: 44),
        textInjection: TextInjectionConfig(clipboardClearDelayMs: 20, clipboardSetDelayMs: 50, pasteWaitDelayMs: 400, modifierReleaseTimeoutSeconds: 2.0),
        model: ModelConfig(defaultTemperature: 0.0, defaultMaxTokens: 4096, warmupDurationSeconds: 8.0, warmupTemperature: 1.0)
    )

    /// Persist this config to the user config file at
    /// ~/Library/Application Support/com.vocaltype.app/config.json
    func save() {
        let userConfigURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.vocaltype.app/config.json")
        let directory = userConfigURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: userConfigURL)
        }
    }
}
