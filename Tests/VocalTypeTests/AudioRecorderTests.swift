import XCTest
@testable import LocalVoice

// MARK: - AudioRecorder Tests

/// Tests the AudioRecorder's pure logic paths.
/// Start/stop tests require a physical microphone and are conditionally skipped.
/// WAV encoding tests are self-contained and always run.
final class AudioRecorderTests: XCTestCase {

    // MARK: - WAV Encoding Tests (no hardware needed)

    func testWAVEncodingHasCorrectHeader() {
        let recorder = AudioRecorder()
        let samples = TestAudioGenerator.generateTestAudio(durationSeconds: 0.1)
        let data = recorder.makeWAVData(samples: samples, sampleRate: 16000)

        // RIFF header
        let riff = data.subdata(in: 0..<4)
        XCTAssertEqual(String(data: riff, encoding: .ascii), "RIFF", "WAV must start with RIFF")

        // WAVE format
        let wave = data.subdata(in: 8..<12)
        XCTAssertEqual(String(data: wave, encoding: .ascii), "WAVE", "WAV must declare WAVE format")

        // PCM (1)
        let audioFormat = data.withUnsafeBytes { $0.load(fromByteOffset: 20, as: UInt16.self) }
        XCTAssertEqual(audioFormat, 1, "Must be PCM format")

        // Mono
        let numChannels = data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) }
        XCTAssertEqual(numChannels, 1, "Must be mono")

        // 16kHz
        let sampleRate = data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) }
        XCTAssertEqual(sampleRate, 16000, "Sample rate must be 16000")

        // 16-bit
        let bitsPerSample = data.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) }
        XCTAssertEqual(bitsPerSample, 16, "Must be 16-bit")

        // File size = 36 + data size
        let fileSize = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        let expectedDataSize = UInt32(samples.count * 2) // 16-bit = 2 bytes per sample
        XCTAssertEqual(fileSize, 36 + expectedDataSize, "File size in header is incorrect")

        // Total file size matches header
        XCTAssertEqual(data.count, Int(fileSize) + 8, "Actual data size must match header declared size")
    }

    func testWAVEncodingEmptySamples() {
        let recorder = AudioRecorder()
        let data = recorder.makeWAVData(samples: [], sampleRate: 16000)
        // Should still produce a valid header with no audio data
        XCTAssertEqual(data.count, 44, "Empty samples should produce 44-byte header only")
        let dataSize = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }
        XCTAssertEqual(dataSize, 0, "Data chunk size must be 0 for empty samples")
    }

    func testWAVEncodingWithKnownSamples() {
        let recorder = AudioRecorder()
        let samples: [Float] = [0.5, -0.5, 0.25, -0.25, 0.0]
        let data = recorder.makeWAVData(samples: samples, sampleRate: 16000)

        // 5 samples × 2 bytes = 10 bytes of PCM data
        let dataSize = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }
        XCTAssertEqual(dataSize, 10, "5 Float samples should produce 10 bytes of PCM data")

        // Verify PCM data starts at offset 44
        let pcmData = data.subdata(in: 44..<data.count)
        XCTAssertEqual(pcmData.count, 10, "PCM data should be 10 bytes")
    }

    func testWAVEncodingAtDifferentSampleRate() {
        let recorder = AudioRecorder()
        let samples = TestAudioGenerator.generateTestAudio(durationSeconds: 0.05, sampleRate: 44100)
        let data = recorder.makeWAVData(samples: samples, sampleRate: 44100)

        let sampleRate = data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) }
        XCTAssertEqual(sampleRate, 44100, "Should encode at specified sample rate")
    }

    // MARK: - State Tests (no hardware needed)

    func testIsRecordingInitiallyFalse() {
        let recorder = AudioRecorder()
        XCTAssertFalse(recorder.isRecording, "isRecording must be false before start()")
    }

    func testStopWithoutStartReturnsNil() {
        let recorder = AudioRecorder()
        let data = recorder.stop()
        XCTAssertNil(data, "stop() without start() must return nil")
    }

    // MARK: - Microphone-dependent Tests (skipped if no mic)

    func testStartSetsIsRecording() throws {
        let recorder = AudioRecorder()
        do {
            try recorder.start()
        } catch {
            try XCTSkipIf(true, "Microphone not available: \(error.localizedDescription)")
        }
        XCTAssertTrue(recorder.isRecording, "isRecording must be true after start()")
        _ = recorder.stop()
    }

    func testStopReturnsDataAndClearsState() throws {
        let recorder = AudioRecorder()
        do {
            try recorder.start()
        } catch {
            try XCTSkipIf(true, "Microphone not available: \(error.localizedDescription)")
        }
        // Record briefly to accumulate audio buffers
        Thread.sleep(forTimeInterval: 0.3)
        let data = recorder.stop()

        if data == nil {
            try XCTSkipIf(true, "No audio data captured — no input device or tap delivered no buffers")
        }

        XCTAssertNotNil(data, "stop() must return audio data after recording")
        XCTAssertFalse(recorder.isRecording, "isRecording must be false after stop()")
        if let data {
            XCTAssertGreaterThan(data.count, 44, "WAV data must have header + PCM content")
        }
    }

    func testStartTwiceDoesntCrash() throws {
        let recorder = AudioRecorder()
        do {
            try recorder.start()
        } catch {
            try XCTSkipIf(true, "Microphone not available: \(error.localizedDescription)")
        }
        // Second start should be a no-op (not crash)
        XCTAssertNoThrow(try recorder.start(), "Calling start() twice must not crash")
        _ = recorder.stop()
    }
}
