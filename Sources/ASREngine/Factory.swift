//
// Factory.swift
// LocalVoice
//
// Abstract factory for creating ASR transcriber instances
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

/// Abstract factory for creating ASR transcriber instances.
/// Add new cases as more models are supported.
public enum ASRModelType: String, CaseIterable {
    case qwen306B = "Qwen3-ASR-0.6B"
    case qwen317B = "Qwen3-ASR-1.7B"
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .qwen306B: return "Qwen3-ASR 0.6B"
        case .qwen317B: return "Qwen3-ASR 1.7B"
        }
    }
    
    /// Create a transcriber instance for this model type.
    func createTranscriber(from directory: URL) async throws -> any ASRTranscriber {
        switch self {
        case .qwen306B, .qwen317B:
            return try await Qwen3ASRSTT.loadWithWarmup(from: directory)
        }
    }
}
