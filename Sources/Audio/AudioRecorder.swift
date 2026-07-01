//
// AudioRecorder.swift
// LocalVoice
//
// 16kHz mono audio capture via AVAudioEngine
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

@preconcurrency import AVFoundation
import Accelerate
import os

// MARK: - Audio Recorder

/// Records audio from the default input device using AVAudioEngine,
/// converts to 16kHz mono Float32, and returns WAV data.
final class AudioRecorder: @unchecked Sendable {
    private let config: AppConfig
    private let engine = AVAudioEngine()
    private var targetSampleRate: Double { config.recording.sampleRate }
    private var converter: AVAudioConverter?
    /// Protected by `framesLock`. Written from AVAudioEngine tap callback (arbitrary thread);
    /// read from MainActor (partial transcription) and tap callback itself.
    private var accumulatedFrames: [Float] = []
    private let framesLock = OSAllocatedUnfairLock(initialState: ())
    private var startTime: Date?

    init(config: AppConfig = AppConfig.defaults) {
        self.config = config
    }

    /// Whether the recorder is currently recording.
    var isRecording: Bool { engine.isRunning }

    /// Snapshot of accumulated audio samples (thread-safe, for partial transcription).
    /// Returns a copy — safe to read from any thread while the tap callback appends.
    var currentSamples: [Float] {
        framesLock.withLock { accumulatedFrames }
    }

    // MARK: - Silence Detection (VAD)

    /// Callback when silence (pause) is detected after speech.
    var onSilenceDetected: (() -> Void)?

    private var lastSpeechTime: Date = Date()
    private var silenceTimer: DispatchSourceTimer?
    private let silenceQueue = DispatchQueue(label: "com.vocaltype.vad")

    /// Adaptive noise floor: calibrated from the first ~500ms of each recording.
    /// Speech threshold = noiseFloor * speechMultiplier (default 3×).
    private var adaptiveNoiseFloor: Float = 0
    private var isCalibrating: Bool = true
    private let calibrationSamples = 8000    // ~500ms at 16kHz
    private let speechMultiplier: Float = 3.0

    /// Effective silence threshold: adaptive floor when calibrated, else config value.
    private var effectiveSilenceThreshold: Float {
        adaptiveNoiseFloor > 0
            ? adaptiveNoiseFloor * speechMultiplier
            : config.vad.silenceThreshold
    }

    /// Start monitoring for silence.
    func startSilenceDetection() {
        lastSpeechTime = Date()
        adaptiveNoiseFloor = 0
        isCalibrating = true
        silenceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: silenceQueue)
        timer.schedule(deadline: .now() + config.vad.checkIntervalSeconds, repeating: config.vad.checkIntervalSeconds)
        timer.setEventHandler { [weak self] in
            self?.checkSilence()
        }
        timer.resume()
        silenceTimer = timer
    }

    /// Stop silence monitoring.
    func stopSilenceDetection() {
        silenceTimer?.cancel()
        silenceTimer = nil
    }

    private func checkSilence() {
        let now = Date()
        let snapshot = framesLock.withLock { accumulatedFrames }
        guard !snapshot.isEmpty else { return }

        // Calibration phase: measure background noise from first ~500ms
        if isCalibrating {
            if snapshot.count >= calibrationSamples {
                let calibWindow = Array(snapshot.prefix(calibrationSamples))
                let noiseRMS = sqrt(calibWindow.reduce(0) { $0 + $1 * $1 } / Float(calibrationSamples))
                adaptiveNoiseFloor = noiseRMS
                isCalibrating = false
                AppLogger.shared.info("🎙️ VAD calibrated: noiseFloor=\(String(format:"%.4f", noiseRMS)), speechThreshold=\(String(format:"%.4f", noiseRMS * speechMultiplier))")
            }
            // Still calibrating — don't trigger VAD yet
            return
        }

        // Compute RMS of last ~checkInterval of audio
        let windowSize = min(config.vad.windowSamplesForRMS, snapshot.count)
        let recentSamples = snapshot.suffix(windowSize)
        let rms = sqrt(recentSamples.reduce(0) { $0 + $1 * $1 } / Float(windowSize))
        let threshold = effectiveSilenceThreshold
        let silent = rms <= threshold
        let elapsed = now.timeIntervalSince(lastSpeechTime)

        if !silent {
            lastSpeechTime = now  // Still speaking
            AppLogger.shared.debug("🎤 VAD: speech (rms=\(String(format:"%.4f",rms)) > threshold=\(String(format:"%.4f",threshold)))")
        } else if elapsed > config.vad.silenceDurationSeconds {
            // Silence detected after speech
            AppLogger.shared.info("🔇 VAD: silence detected (rms=\(String(format:"%.4f",rms)) ≤ threshold=\(String(format:"%.4f",threshold)), elapsed=\(String(format:"%.1f",elapsed))s)")
            onSilenceDetected?()
            lastSpeechTime = now  // Reset to avoid repeated triggers
        }
    }

    /// Start recording. Must check microphone permission first.
    func start() throws {
        AppLogger.shared.info("🎙️ Recording started")
        guard !engine.isRunning else { return }
        framesLock.withLock {
            accumulatedFrames = []
            accumulatedFrames.reserveCapacity(Int(targetSampleRate * 30)) // 30 seconds
        }

        let input = engine.inputNode
        let origFormat = input.outputFormat(forBus: 0)

        // Convert to 16kHz mono Float32
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatConversionFailed
        }

        // Create converter once before installing the tap
        converter = AVAudioConverter(from: origFormat, to: format)

        // Install a tap on the input node, converting to our target format
        input.installTap(onBus: 0, bufferSize: 4096, format: origFormat) { [weak self] buffer, _ in
            // Convert buffer to target format
            guard let self, let converter = self.converter else { return }
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / origFormat.sampleRate)
            )!

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, status in
                status.pointee = .haveData
                return buffer
            }

            if let floatData = convertedBuffer.floatChannelData {
                let frames = convertedBuffer.frameLength
                let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(frames)))
                self.framesLock.withLock { self.accumulatedFrames.append(contentsOf: samples) }
            }
        }

        let hardwareFormat = engine.inputNode.outputFormat(forBus: 0)
        try engine.start()
        AppLogger.shared.info("🎤 Audio engine started: format=\(hardwareFormat)")
        startTime = Date()
        startSilenceDetection()
    }

    /// Stop recording and return the audio as WAV data.
    func stop() -> Data? {
        stopSilenceDetection()
        guard engine.isRunning else { return nil }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        startTime = nil

        let frames = framesLock.withLock { accumulatedFrames }
        guard !frames.isEmpty else { return nil }

        let samples = frames.count
        let peak = frames.map { abs($0) }.max() ?? 0
        let nonZero = frames.filter { abs($0) > 0.001 }.count
        AppLogger.shared.info("🎙️ Recording stopped: \(samples) samples")
        AppLogger.shared.info("🎧 Audio: \(samples) samples, peak=\(peak), nonZero=\(nonZero)/\(samples)")

        return makeWAVData(samples: frames, sampleRate: targetSampleRate)
    }

    /// Get the recording duration so far (for UI updates).
    func currentDuration() -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - WAV Encoding

    /// Encode float samples to 16-bit mono WAV.
    func makeWAVData(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()

        // Convert Float32 → Int16 with rounding
        var int16Samples = [Int16](repeating: 0, count: samples.count)
        var scale = Float(Int16.max)
        var scaled = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, &scale, &scaled, 1, vDSP_Length(samples.count))
        vDSP_vfixr16(scaled, 1, &int16Samples, 1, vDSP_Length(scaled.count))

        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerFrame = numChannels * (bitsPerSample / 8)
        let byteRate = UInt32(sampleRate) * UInt32(bytesPerFrame)
        let dataSize = UInt32(int16Samples.count) * UInt32(bytesPerFrame)
        let fileSize = 36 + dataSize

        // WAV header (44 bytes)
        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })        // chunk size
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })          // PCM
        header.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bytesPerFrame.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        data.append(header)
        data.append(Data(bytes: &int16Samples, count: int16Samples.count * 2))

        return data
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case formatConversionFailed

    var errorDescription: String? {
        switch self {
        case .formatConversionFailed: return "Failed to create 16kHz audio format"
        }
    }
}
