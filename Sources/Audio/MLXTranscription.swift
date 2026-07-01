//
// MLXTranscription.swift
// LocalVoice
//
// MLX-based transcription implementation
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation
import MLX
import ASREngine
import os

// MARK: - Transcription Errors

enum TranscriptionError: Error, LocalizedError {
    case modelNotLoaded
    case invalidAudioData
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Speech recognition model is not loaded. Please download the model first."
        case .invalidAudioData:
            return "Invalid audio data format."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

// MARK: - MLX Transcription Service

/// Real transcription service using MLX + Qwen3-ASR (inlined source).
///
/// The Qwen3ASRSTT actor from ASREngine handles:
/// - Model loading with quantization support (5-bit affine)
/// - Audio preprocessing (128-bin log-mel spectrogram, 400 FFT, Slaney filterbank)
/// - Audio encoding (Conv2d frontend + 24-layer transformer encoder)
/// - Text decoding (28-layer Qwen3 decoder with GQA, QK norm, RoPE, KV cache)
/// - Token generation with repetition detection
/// - Metal JIT warmup for fast first inference
final class MLXTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private let sttLock = OSAllocatedUnfairLock(initialState: Optional<Qwen3ASRSTT>.none)

    var isLoaded: Bool {
        sttLock.withLock { $0 != nil }
    }

    func loadModel(at url: URL) async throws {
        AppLogger.shared.info("Loading Qwen3-ASR model from \(url.path)")
        let loaded = try await Qwen3ASRSTT.loadWithWarmup(from: url)
        sttLock.withLock { $0 = loaded }
        AppLogger.shared.info("✅ Model loaded and warmed up")
    }

    func transcribe(audioData: Data, language: String? = nil) async throws -> String {
        let currentSTT = sttLock.withLock { $0 }

        guard let currentSTT else {
            throw TranscriptionError.modelNotLoaded
        }

        let samples = wavDataToFloat(audioData)
        guard !samples.isEmpty else {
            throw TranscriptionError.invalidAudioData
        }

        AppLogger.shared.info("🧠 Transcription started: \(samples.count) samples, language=\(language ?? "auto")")
        do {
            let result = try await currentSTT.transcribe(audio: samples, language: language)
            AppLogger.shared.info("✅ Transcribed \(samples.count) samples → \(result.text.count) chars, RTF=\(result.rtf)")
            return result.text
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    func unloadModel() {
        sttLock.withLock { $0 = nil }
        MLX.Memory.clearCache()
        AppLogger.shared.info("Model unloaded, memory cleared")
    }

    // MARK: - WAV to Float conversion

    /// Convert WAV data (16kHz, 16-bit, mono) to Float samples normalized to [-1, 1].
    /// Skips the standard 44-byte WAV header.
    private func wavDataToFloat(_ data: Data) -> [Float] {
        // Standard WAV header is 44 bytes
        guard data.count > 44 else { return [] }
        let pcmData = data.subdata(in: 44..<data.count)
        let count = pcmData.count / MemoryLayout<Int16>.stride
        guard count > 0 else { return [] }
        return pcmData.withUnsafeBytes { ptr in
            let int16 = ptr.bindMemory(to: Int16.self)
            return (0..<count).map { Float(int16[$0]) / Float(Int16.max) }
        }
    }
}
