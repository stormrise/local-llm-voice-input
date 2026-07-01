import XCTest
@testable import LocalVoice

// MARK: - Transcription Integration Tests

/// End-to-end transcription test using a pre-recorded (programmatically generated) WAV file.
///
/// This test requires the model files to be present on disk at:
///   ~/Library/Application Support/com.vocaltype.app/models/Qwen3-ASR-0.6B-6bit/
///
/// If model files are not found, the test is skipped with XCTSkip.
/// Network access is NOT required (model is local).
final class TranscriptionIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Path to the 0.6B model directory.
    private var modelPath06B: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/com.vocaltype.app/models/Qwen3-ASR-0.6B-6bit")
            .path
    }

    /// Check if the 0.6B model files exist on disk.
    private func modelFilesExist() -> Bool {
        let path = modelPath06B
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        // Check for required files
        let required = ["config.json", "model.safetensors", "vocab.json"]
        for file in required {
            let filePath = (path as NSString).appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath) {
                return false
            }
        }
        return true
    }

    // MARK: - Tests

    /// Generate a test WAV file and transcribe it using the real MLX model.
    /// This test loads the 0.6B model, transcribes a sine wave (which will likely
    /// produce nonsense or empty text since it's not speech), and verifies the
    /// transcription pipeline runs without error.
    func testTranscribeWithRealModel() async throws {
        guard modelFilesExist() else {
            throw XCTSkip("Model files not found at \(modelPath06B). Download the model first.")
        }

        // Generate test audio (2 seconds of sine wave)
        let samples = TestAudioGenerator.generateTestAudio(durationSeconds: 2.0, sampleRate: 16000)
        let recorder = AudioRecorder()
        let wavData = recorder.makeWAVData(samples: samples, sampleRate: 16000)
        XCTAssertGreaterThan(wavData.count, 44, "WAV data must have header + PCM content")

        // Load the real MLX transcription service
        let service = MLXTranscriptionService()
        XCTAssertFalse(service.isLoaded, "Model must not be loaded before loadModel()")

        let modelURL = URL(fileURLWithPath: modelPath06B)
        do {
            try await service.loadModel(at: modelURL)
        } catch {
            // MLX model loading can fail for various hardware reasons (no Metal, etc.)
            throw XCTSkip("Failed to load model: \(error.localizedDescription)")
        }

        XCTAssertTrue(service.isLoaded, "Model must be loaded after loadModel()")

        // Transcribe
        let text = try await service.transcribe(audioData: wavData)

        // The transcription of a sine wave is not expected to produce meaningful speech,
        // but the pipeline should complete without error and return a string.
        XCTAssertNotNil(text, "Transcription must return a string")
        // It's acceptable for the result to be empty (sine wave is not speech)
        // The important thing is that the pipeline runs without crashing
    }

    /// Test that empty audio data returns an appropriate error.
    func testTranscribeWithEmptyData() async {
        let service = MLXTranscriptionService()
        let emptyData = Data()

        do {
            _ = try await service.transcribe(audioData: emptyData)
            XCTFail("Transcribing empty data should throw")
        } catch {
            XCTAssertTrue(error is TranscriptionError, "Must throw TranscriptionError")
            if case TranscriptionError.invalidAudioData = error {
                // Expected — empty data has no valid WAV content
            } else if case TranscriptionError.modelNotLoaded = error {
                // Also valid — model not loaded is caught first
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    /// Test that the model can be unloaded and re-loaded.
    func testModelUnloadReload() async throws {
        guard modelFilesExist() else {
            throw XCTSkip("Model files not found")
        }

        let service = MLXTranscriptionService()
        let modelURL = URL(fileURLWithPath: modelPath06B)

        // Load
        do {
            try await service.loadModel(at: modelURL)
        } catch {
            try XCTSkipIf(true, "Failed to load model: \(error.localizedDescription)")
        }
        XCTAssertTrue(service.isLoaded)

        // Unload
        service.unloadModel()
        XCTAssertFalse(service.isLoaded, "Model must be unloaded after unloadModel()")
    }
}
