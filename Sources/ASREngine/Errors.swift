//
// Errors.swift
// LocalVoice
//
// Error types for ASR engine
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

// MARK: - ASR Errors

/// Errors that can occur during ASR operations
public enum ASRError: Error, LocalizedError, ASRErrorProtocol {
    case modelLoadFailed(String)
    case audioLoadFailed(String)
    case transcriptionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let msg): return "Model load failed: \(msg)"
        case .audioLoadFailed(let msg): return "Audio load failed: \(msg)"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        }
    }
}
