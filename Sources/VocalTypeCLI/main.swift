//
// main.swift
// LocalVoice
//
// CLI entry point for testing transcription
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation
import ASREngine

@main
enum LocalVoiceCLI {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            print("Usage: LocalVoiceCLI <wav_file>")
            exit(1)
        }
        let wavPath = args[1]

        // Find model directory
        let home = FileManager.default.homeDirectoryForCurrentUser
        let modelDir = home.appendingPathComponent("Library/Application Support/com.vocaltype.app/models/Qwen3-ASR-0.6B-6bit")
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            print("Model not found at \(modelDir.path)")
            exit(1)
        }

        // Load WAV file
        guard let wavData = try? Data(contentsOf: URL(fileURLWithPath: wavPath)) else {
            print("Failed to read WAV file at \(wavPath)")
            exit(1)
        }
        guard wavData.count > 44 else {
            print("Invalid WAV file: too small (\(wavData.count) bytes)")
            exit(1)
        }
        let pcmData = wavData.dropFirst(44)
        let samples: [Float] = pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            return (0 ..< int16Ptr.count).map { Float(int16Ptr[$0]) / 32768.0 }
        }
        print("📁 Loaded WAV: \(samples.count) samples, duration=\(Double(samples.count) / 16000.0)s")

        let absMax = samples.map(abs).max() ?? 0
        let avg = samples.reduce(0, +) / Float(samples.count)
        print("   Audio stats: mean=\(avg), abs_max=\(absMax), nonzero=\(samples.filter { $0 != 0 }.count)/\(samples.count)")

        // Load model
        print("🔧 Loading model from \(modelDir.path)...")
        let stt: Qwen3ASRSTT
        do {
            stt = try await Qwen3ASRSTT.load(from: modelDir)
        } catch {
            print("❌ Model load failed: \(error)")
            exit(1)
        }
        print("✅ Model loaded")

        // Test with warmup noise
        print("🎙️ Transcribing NOISE (temp=1.0, should generate random tokens)...")
        var noise = [Float](repeating: 0, count: 64000)
        for i in 0..<64000 { noise[i] = Float.random(in: -0.01...0.01) }
        do {
            let result = try await stt.transcribe(audio: noise, maxTokens: 32, temperature: 1.0)
            print("   Noise result (\(result.text.count) chars): \"\(result.text.prefix(50))\"")
        } catch {
            print("   ❌ Noise failed: \(error)")
        }

        // Then test with real audio
        print("🎙️ Transcribing (greedy, lang=Chinese)...")
        do {
            let result = try await stt.transcribe(audio: samples, language: "Chinese", maxTokens: 128)
            print("   Result: \"\(result.text)\"")
            print("   RTF: \(String(format: "%.3f", result.rtf))")
        } catch {
            print("   ❌ Failed: \(error)")
        }

        // Try with temp=0.5 + Chinese language 
        print("🎙️ Transcribing (temp=0.5, lang=Chinese)...")
        do {
            let result = try await stt.transcribe(audio: samples, language: "Chinese", maxTokens: 128, temperature: 0.5)
            print("   Result: \"\(result.text)\"")
            print("   RTF: \(String(format: "%.3f", result.rtf))")
        } catch {
            print("   ❌ Failed: \(error)")
        }

        // Also try auto language
        print("🎙️ Transcribing (temp=0.5, lang=auto)...")
        do {
            let result = try await stt.transcribe(audio: samples, language: "auto", maxTokens: 128, temperature: 0.5)
            print("   Result: \"\(result.text)\"")
            print("   RTF: \(String(format: "%.3f", result.rtf))")
        } catch {
            print("   ❌ Failed: \(error)")
        }
    }
}
