//
// Qwen3ASRTokenizer.swift
// LocalVoice
//
// Tokenizer for Qwen3-ASR (prompt building, parsing)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation
import Tokenizers

/// Qwen3-ASR tokenizer wrapper
///
/// Uses swift-transformers AutoTokenizer for Qwen3 tokenization.
/// Handles special tokens for audio speech recognition.
public final class Qwen3ASRTokenizer {
    private let tokenizer: Tokenizer

    // Special token IDs
    public let audioTokenId: Int
    public let audioStartTokenId: Int
    public let audioEndTokenId: Int
    public let eosTokenIds: Set<Int>

    // Special token IDs (matching Qwen3 standard)
    private let imStartTokenId = 151644
    private let imEndTokenId = 151645

    // Special token strings (kept for reference / debug printing; buildPrompt uses numeric IDs)
    private let imStartToken = "<|im_start|>"
    private let imEndToken = "<|im_end|>"
    private let audioStartToken = "<|audio_start|>"
    private let audioEndToken = "<|audio_end|>"
    private let audioPadToken = "<|audio_pad|>"

    // Reverse vocabulary: token ID → original token string
    // (decode() strips control tokens, so we use this for EOS detection)
    private let idToToken: [Int: String]

    private init(
        tokenizer: Tokenizer,
        audioTokenId: Int,
        audioStartTokenId: Int,
        audioEndTokenId: Int,
        idToToken: [Int: String]
    ) {
        self.tokenizer = tokenizer
        self.idToToken = idToToken
        self.audioTokenId = audioTokenId
        self.audioStartTokenId = audioStartTokenId
        self.audioEndTokenId = audioEndTokenId

        // Build EOS token set
        var eosIds = Set<Int>()
        // Standard Qwen3 EOS tokens
        eosIds.insert(151645) // <|im_end|>
        eosIds.insert(151643) // <|endoftext|>
        if let tokenizerEos = tokenizer.eosTokenId {
            eosIds.insert(tokenizerEos)
        }
        eosTokenIds = eosIds
    }

    /// Load tokenizer from model directory
    ///
    /// - Parameters:
    ///   - modelDirectory: Path to model directory
    ///   - config: Qwen3-ASR configuration
    /// - Returns: Initialized tokenizer
    public static func load(
        from modelDirectory: URL,
        config: Qwen3ASRConfig
    ) async throws -> Qwen3ASRTokenizer {
        try generateTokenizerJsonIfNeeded(in: modelDirectory)
        let tokenizer = try await AutoTokenizer.from(modelFolder: modelDirectory)

        // Build reverse vocabulary: token ID → original token string
        let vocabPath = modelDirectory.appendingPathComponent("vocab.json")
        let vocabData = try Data(contentsOf: vocabPath)
        let vocab = try JSONDecoder().decode([String: Int].self, from: vocabData)
        var idToToken: [Int: String] = [:]
        for (token, id) in vocab {
            idToToken[id] = token
        }

        return Qwen3ASRTokenizer(
            tokenizer: tokenizer,
            audioTokenId: config.audioTokenId,
            audioStartTokenId: config.audioStartTokenId,
            audioEndTokenId: config.audioEndTokenId,
            idToToken: idToToken
        )
    }

    /// Encode text to token IDs
    public func encode(_ text: String) -> [Int] {
        tokenizer.encode(text: text)
    }

    /// Decode token IDs to text
    public func decode(_ tokens: [Int]) -> String {
        tokenizer.decode(tokens: tokens)
    }

    /// Check if token is an EOS token (by ID or raw token string)
    public func isEosToken(_ tokenId: Int) -> Bool {
        // Fast path: known EOS token IDs
        if eosTokenIds.contains(tokenId) {
            return true
        }
        // Fallback: check the raw token string from vocabulary.
        // decode() strips control tokens (e.g. <|im_end|> → ""),
        // so we use a vocab reverse-lookup instead.
        if let tokenStr = idToToken[tokenId],
           tokenStr.contains("<|im_") && tokenStr.contains("end|>") {
            return true
        }
        return false
    }

    /// Build prompt for transcription
    ///
    /// Format:
    /// ```
    /// <|im_start|>system
    /// <|im_end|>
    /// <|im_start|>user
    /// <|audio_start|><|audio_pad|>...<|audio_end|><|im_end|>
    /// <|im_start|>assistant
    /// language English<asr_text>
    /// ```
    ///
    /// Assembles token IDs directly — special tokens use their numeric IDs
    /// (151644, 151645, 151676, etc.) while natural language text is BPE-encoded.
    /// This ensures `<|audio_pad|>` tokens appear as `audioTokenId` (151676)
    /// in the output, so `findAudioTokenPositions()` can locate them and
    /// `buildInputsEmbeds()` can merge audio features.
    ///
    /// - Parameters:
    ///   - numAudioTokens: Number of audio tokens (determines audio_pad count)
    ///   - language: Target language for transcription (omit/auto for detection)
    ///   - context: Optional system-prompt context for hotword biasing
    /// - Returns: Encoded prompt token IDs
    public func buildPrompt(
        numAudioTokens: Int,
        language: String? = "English",
        context: String? = nil
    ) -> [Int] {
        let audioTokens = String(repeating: audioPadToken, count: numAudioTokens)
        let languageLine: String
        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           language.lowercased() != "auto"
        {
            languageLine = "language \(language)<asr_text>"
        } else {
            languageLine = "<asr_text>"
        }
        let systemContext = context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let systemLine = systemContext.isEmpty ? "" : "\(systemContext)\n"

        let prompt = """
            \(imStartToken)system
            \(systemLine)\(imEndToken)
            \(imStartToken)user
            \(audioStartToken)\(audioTokens)\(audioEndToken)\(imEndToken)
            \(imStartToken)assistant
            \(languageLine)
            """
        
        let result = encode(prompt)
        // Debug: check if audio tokens are encoded as single 151676 or BPE subwords
        let audio151676Count = result.filter { $0 == audioTokenId }.count
        print("📋 BPE buildPrompt: \(result.count) tokens, audioTokenId=\(audioTokenId), matches=\(audio151676Count), expected=\(numAudioTokens)")
        return result
    }

    /// Find audio token positions in token IDs
    ///
    /// - Parameter tokenIds: Array of token IDs
    /// - Returns: Range of audio token positions (indices to replace with audio features)
    public func findAudioTokenPositions(_ tokenIds: [Int]) -> Range<Int>? {
        var startIdx: Int?
        var endIdx: Int?

        for (i, tokenId) in tokenIds.enumerated() {
            if tokenId == audioStartTokenId, startIdx == nil {
                startIdx = i + 1 // Start after audio_start token
            }
            if tokenId == audioEndTokenId, endIdx == nil {
                endIdx = i // End before audio_end token
            }
        }

        if let start = startIdx, let end = endIdx, start < end {
            return start ..< end
        }
        return nil
    }

    /// Parse generated output into text + optional detected language.
    public func parseOutput(_ text: String) -> (text: String, language: String?) {
        var cleaned = text

        // Remove ALL Qwen-family special tokens: <|im_start|>, <|im_0_end|>, <|im_1_end|>, etc.
        // Different model versions/quantizations use slightly different token names,
        // so a regex is more robust than a hardcoded list.
        // (?s) enables dot-matches-newline so tokens spanning newlines are caught.
        let specialTokenPattern = "(?s)<\\|[^|]*\\|>"
        if let regex = try? NSRegularExpression(pattern: specialTokenPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }

        // Also remove non-token special markers
        let extraTokens = ["<asr_text>", "</asr_text>"]
        for token in extraTokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }

        var detectedLanguage: String?
        // Remove language prefix if present
        if cleaned.hasPrefix("language ") {
            if let range = cleaned.range(of: "\n") {
                let line = cleaned[..<range.lowerBound]
                detectedLanguage = line.replacingOccurrences(of: "language ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = String(cleaned[range.upperBound...])
            } else {
                detectedLanguage = cleaned.replacingOccurrences(of: "language ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = ""
            }
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, detectedLanguage)
    }

    /// Clean generated output text
    public func cleanOutput(_ text: String) -> String {
        parseOutput(text).text
    }

    // MARK: - tokenizer.json Generation

    /// Generate tokenizer.json from multi-file tokenizer format if missing.
    ///
    /// Qwen3 models ship vocab.json + merges.txt + tokenizer_config.json
    /// (the legacy HuggingFace multi-file format), but swift-transformers'
    /// AutoTokenizer requires a single tokenizer.json. This method reads
    /// the separate files and synthesizes the combined BPE JSON.
    private static func generateTokenizerJsonIfNeeded(in modelDirectory: URL) throws {
        let tokenizerJsonURL = modelDirectory.appendingPathComponent("tokenizer.json")
        guard !FileManager.default.fileExists(atPath: tokenizerJsonURL.path) else { return }

        // Read vocab.json — { "token": id, ... }
        let vocabURL = modelDirectory.appendingPathComponent("vocab.json")
        let vocabData = try Data(contentsOf: vocabURL)
        guard let vocab = try JSONSerialization.jsonObject(with: vocabData) as? [String: Int] else {
            print("⚠️ vocab.json has unexpected format, using empty vocab")
            throw TokenizerGenerationError.invalidVocab
        }

        // Read merges.txt — one merge pair per line: "token1 token2"
        let mergesURL = modelDirectory.appendingPathComponent("merges.txt")
        let mergesContent = try String(contentsOf: mergesURL, encoding: .utf8)
        let merges = mergesContent
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        // Read added_tokens_decoder from tokenizer_config.json if present
        var addedTokensDecoder: [String: Any] = [:]
        let configURL = modelDirectory.appendingPathComponent("tokenizer_config.json")
        if FileManager.default.fileExists(atPath: configURL.path) {
            let configData = try Data(contentsOf: configURL)
            if let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any],
               let atd = config["added_tokens_decoder"] as? [String: Any] {
                addedTokensDecoder = atd
            }
        }

        // Build added_tokens array from added_tokens_decoder (needed for encoding)
        var addedTokens: [[String: Any]] = []
        for (id, value) in addedTokensDecoder.sorted(by: { Int($0.key)! < Int($1.key)! }) {
            if var tokenInfo = value as? [String: Any] {
                tokenInfo["id"] = Int(id)
                addedTokens.append(tokenInfo)
            }
        }

        // Build the combined tokenizer.json structure for a BPE ByteLevel tokenizer
        let tokenizerJson: [String: Any] = [
            "version": "1.0",
            "added_tokens": addedTokens,
            "added_tokens_decoder": addedTokensDecoder,
            "normalizer": ["type": "NFC"],
            "pre_tokenizer": [
                "type": "ByteLevel",
                "add_prefix_space": false,
                "use_regex": true,
            ],
            "post_processor": ["type": "ByteLevel"],
            "decoder": ["type": "ByteLevel", "use_regex": true],
            "model": [
                "type": "BPE",
                "vocab": vocab,
                "merges": merges,
            ],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: tokenizerJson, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: tokenizerJsonURL)

        print("Generated tokenizer.json from multi-file format")
    }
}

// MARK: - Tokenizer Generation Errors

enum TokenizerGenerationError: LocalizedError {
    case invalidVocab

    var errorDescription: String? {
        switch self {
        case .invalidVocab: return "vocab.json is not a valid [String: Int] dictionary"
        }
    }
}
