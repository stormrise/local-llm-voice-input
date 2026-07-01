import XCTest
import Foundation

// MARK: - Test Audio Generator

enum TestAudioGenerator {
    /// Generate a sine wave audio buffer in Float format.
    /// - Parameters:
    ///   - durationSeconds: Length of audio in seconds.
    ///   - sampleRate: Sample rate in Hz (default 16kHz for VocalType).
    /// - Returns: Array of Float samples normalized to [-1, 1].
    static func generateTestAudio(durationSeconds: Double = 1.0, sampleRate: Double = 16000) -> [Float] {
        let frameCount = Int(durationSeconds * sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)
        let frequency: Double = 440.0
        let amplitude: Float = 0.5
        for i in 0..<frameCount {
            let phase = 2.0 * .pi * frequency * Double(i) / sampleRate
            samples[i] = Float(sin(phase)) * amplitude
        }
        return samples
    }
}
