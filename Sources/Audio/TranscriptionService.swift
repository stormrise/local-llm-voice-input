//
// TranscriptionService.swift
// LocalVoice
//
// Transcription service protocol and factory
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

// MARK: - Transcription Service Protocol

/// Protocol for speech-to-text transcription.
protocol TranscriptionServiceProtocol: AnyObject, Sendable {
    /// Whether the model is loaded and ready.
    var isLoaded: Bool { get }

    /// Load a model from the given directory.
    func loadModel(at url: URL) async throws

    /// Transcribe WAV audio data to text.
    /// - Parameters:
    ///   - audioData: WAV file data (16kHz, 16-bit, mono).
    ///   - language: Optional language hint ("Chinese", "English", or nil for auto-detect).
    /// - Returns: Transcribed text.
    func transcribe(audioData: Data, language: String?) async throws -> String

    /// Unload the model to free memory.
    func unloadModel()
}

// MARK: - Stub Transcription Service

/// Stub implementation for testing the UI flow without a real MLX model.
/// Returns placeholder text after a simulated delay.
final class StubTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private(set) var isLoaded = false
    private let simulateDelay: TimeInterval

    init(simulateDelay: TimeInterval = 1.5) {
        self.simulateDelay = simulateDelay
    }

    func loadModel(at url: URL) async throws {
        // Simulate model loading
        try await Task.sleep(for: .seconds(1))
        isLoaded = true
    }

    func transcribe(audioData: Data, language: String? = nil) async throws -> String {
        guard isLoaded else { throw TranscriptionError.modelNotLoaded }

        // Simulate transcription delay
        try await Task.sleep(for: .seconds(simulateDelay))

        // Return different mock text based on audio length (data size)
        let durationSeconds = Double(audioData.count) / 32_000 // rough estimate for 16kHz 16-bit mono
        if durationSeconds < 0.5 {
            return ""
        } else if durationSeconds < 2.0 {
            return "好的，明白。"
        } else {
            return "这是一个测试语音输入。目前使用的是模拟转录服务。当集成MLX模型后，这里会返回真实的语音识别结果。"
        }
    }

    func unloadModel() {
        isLoaded = false
    }
}

// MARK: - Transcription Service Factory

enum TranscriptionServiceFactory {
    /// Create a transcription service for the given engine.
    /// Returns the real MLX service for production use.
    @MainActor
    static func make(engine: STTEngine) -> TranscriptionServiceProtocol {
        // All variants use the same MLX runtime — the quantization is encoded in the weights file
        return MLXTranscriptionService()
    }
}
