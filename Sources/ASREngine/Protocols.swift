//
// Protocols.swift
// LocalVoice
//
// Protocol definitions for ASR transcriber abstraction
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation
import MLX

// MARK: - ASR Transcriber Protocol

/// Protocol for any speech-to-text transcriber (Qwen, Whisper, Parakeet, etc.)
public protocol ASRTranscriber: Actor {
    /// Load a model from a directory (no warmup).
    static func load(from directory: URL) async throws -> Self
    
    /// Load a model with Metal warmup for fast first transcription.
    static func loadWithWarmup(from directory: URL) async throws -> Self
    
    /// Transcribe audio samples to text.
    /// - Parameters:
    ///   - audio: Float array of 16kHz mono audio samples.
    ///   - language: Optional language hint (nil/auto for detection).
    /// - Returns: Transcription result with text and timing metrics.
    func transcribe(audio: [Float], language: String?) throws -> TranscriptionResult
    
    /// Flush MLX memory pool — call after dropping references to free GPU memory.
    static func flushMemoryPool()
    
    /// Keep the model alive with a minimal dummy inference.
    func keepAlive() throws
}

// MARK: - ASR Error Protocol

/// Error types that ASR transcribers can throw.
public protocol ASRErrorProtocol: Error, LocalizedError {
    static func modelLoadFailed(_ message: String) -> Self
    static func audioLoadFailed(_ message: String) -> Self
    static func transcriptionFailed(_ message: String) -> Self
}
