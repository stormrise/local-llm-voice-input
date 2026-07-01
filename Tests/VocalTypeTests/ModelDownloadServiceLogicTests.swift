import XCTest
@testable import LocalVoice

// MARK: - ModelDownloadService Logic Tests

/// Tests for the model download domain logic: STTEngine enum values,
/// repo folder names, download phase transitions.
///
/// These tests do NOT require network access or actual model files.
final class ModelDownloadServiceLogicTests: XCTestCase {

    // MARK: - STTEngine Enum

    func testSTTEngineAllCases() {
        XCTAssertEqual(STTEngine.allCases.count, 9, "Must have exactly 9 engine variants")
        // 0.6B
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR06B4bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR06B5bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR06B6bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR06B8bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR06BBf16))
        // 1.7B
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR17B4bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR17B5bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR17B6bit))
        XCTAssertTrue(STTEngine.allCases.contains(.qwen3ASR17B8bit))
    }

    func testSTTEngineHFRepoIDs() {
        XCTAssertEqual(STTEngine.qwen3ASR06B4bit.hfRepoID, "mlx-community/Qwen3-ASR-0.6B-4bit")
        XCTAssertEqual(STTEngine.qwen3ASR06B5bit.hfRepoID, "mlx-community/Qwen3-ASR-0.6B-5bit")
        XCTAssertEqual(STTEngine.qwen3ASR06B6bit.hfRepoID, "mlx-community/Qwen3-ASR-0.6B-6bit")
        XCTAssertEqual(STTEngine.qwen3ASR06B8bit.hfRepoID, "mlx-community/Qwen3-ASR-0.6B-8bit")
        XCTAssertEqual(STTEngine.qwen3ASR06BBf16.hfRepoID,  "mlx-community/Qwen3-ASR-0.6B-bf16")
        XCTAssertEqual(STTEngine.qwen3ASR17B4bit.hfRepoID, "mlx-community/Qwen3-ASR-1.7B-4bit")
        XCTAssertEqual(STTEngine.qwen3ASR17B5bit.hfRepoID, "mlx-community/Qwen3-ASR-1.7B-5bit")
        XCTAssertEqual(STTEngine.qwen3ASR17B6bit.hfRepoID, "mlx-community/Qwen3-ASR-1.7B-6bit")
        XCTAssertEqual(STTEngine.qwen3ASR17B8bit.hfRepoID, "mlx-community/Qwen3-ASR-1.7B-8bit")
    }

    func testModelscopeRepoIDMatchesHF() {
        for engine in STTEngine.allCases {
            XCTAssertEqual(engine.modelscopeRepoID, engine.hfRepoID,
                           "\(engine.rawValue): modelscopeRepoID must match hfRepoID")
        }
    }

    // MARK: - Repo Folder Names

    func testRepoFolderNamesAreDistinct() {
        let names = STTEngine.allCases.map(\.repoFolderName)
        XCTAssertEqual(Set(names).count, names.count,
                       "Each engine must have a unique folder name")
    }

    func testRepoFolderNameDerivedFromRepoID() {
        for engine in STTEngine.allCases {
            let expected = engine.hfRepoID.components(separatedBy: "/").last!
            XCTAssertEqual(engine.repoFolderName, expected,
                           "\(engine.rawValue): repoFolderName must be the last component of hfRepoID")
        }
    }

    // MARK: - Family

    func testIs06BFamily() {
        let sixTenths: [STTEngine] = [.qwen3ASR06B4bit, .qwen3ASR06B5bit, .qwen3ASR06B6bit,
                                       .qwen3ASR06B8bit, .qwen3ASR06BBf16]
        for e in sixTenths { XCTAssertTrue(e.is06B, "\(e.rawValue) should be 0.6B family") }

        let sevenTenths: [STTEngine] = [.qwen3ASR17B4bit, .qwen3ASR17B5bit,
                                         .qwen3ASR17B6bit, .qwen3ASR17B8bit]
        for e in sevenTenths { XCTAssertFalse(e.is06B, "\(e.rawValue) should be 1.7B family") }
    }

    // MARK: - Recommended

    func testExactlyOneRecommended() {
        let recommended = STTEngine.allCases.filter(\.isRecommended)
        XCTAssertEqual(recommended.count, 1, "Exactly one engine should be recommended")
        XCTAssertEqual(recommended.first, .qwen3ASR06B6bit)
    }

    // MARK: - Required Files

    func testRequiredFilesPresent() {
        let expected = ["config.json", "tokenizer_config.json", "vocab.json",
                        "merges.txt", "preprocessor_config.json", "model.safetensors"]
        for engine in STTEngine.allCases {
            XCTAssertEqual(engine.requiredFiles, expected,
                           "\(engine.rawValue): requiredFiles mismatch")
        }
    }

    // MARK: - ModelDownloadPhase Transitions

    func testDownloadPhaseIdle() {
        let phase = ModelDownloadPhase.idle
        XCTAssertEqual(phase.statusText, "Not downloaded")
        XCTAssertFalse(phase.isActive, "idle must not be active")
    }

    func testDownloadPhaseFetching() {
        let phase = ModelDownloadPhase.fetching
        XCTAssertEqual(phase.statusText, "Fetching file list...")
        XCTAssertTrue(phase.isActive, "fetching must be active")
    }

    func testDownloadPhaseDownloading() {
        let phase = ModelDownloadPhase.downloading
        XCTAssertEqual(phase.statusText, "Downloading...")
        XCTAssertTrue(phase.isActive, "downloading must be active")
    }

    func testDownloadPhaseVerifying() {
        let phase = ModelDownloadPhase.verifying
        XCTAssertEqual(phase.statusText, "Verifying...")
        XCTAssertTrue(phase.isActive, "verifying must be active")
    }

    func testDownloadPhaseCompleted() {
        let phase = ModelDownloadPhase.completed
        XCTAssertEqual(phase.statusText, "Downloaded")
        XCTAssertFalse(phase.isActive, "completed must not be active")
    }

    func testDownloadPhaseRetrying() {
        let phase = ModelDownloadPhase.retrying(3, "Connection timeout")
        XCTAssertTrue(phase.statusText.hasPrefix("Retry 3/10..."),
                      "Retry status must show attempt number")
        XCTAssertTrue(phase.isActive, "retrying must be active")
    }

    func testDownloadPhaseFailed() {
        let phase = ModelDownloadPhase.failed("Network error")
        XCTAssertEqual(phase.statusText, "Failed: Network error")
        XCTAssertFalse(phase.isActive, "failed must not be active")
    }

    func testDownloadPhaseEquality() {
        XCTAssertEqual(ModelDownloadPhase.idle, ModelDownloadPhase.idle)
        XCTAssertEqual(ModelDownloadPhase.fetching, ModelDownloadPhase.fetching)
        XCTAssertEqual(ModelDownloadPhase.completed, ModelDownloadPhase.completed)
        XCTAssertNotEqual(ModelDownloadPhase.idle, ModelDownloadPhase.fetching)
        XCTAssertEqual(ModelDownloadPhase.retrying(1, "err"), ModelDownloadPhase.retrying(1, "err"))
        XCTAssertNotEqual(ModelDownloadPhase.retrying(1, "err"), ModelDownloadPhase.retrying(2, "err"))
        XCTAssertEqual(ModelDownloadPhase.failed("err"), ModelDownloadPhase.failed("err"))
        XCTAssertNotEqual(ModelDownloadPhase.failed("err1"), ModelDownloadPhase.failed("err2"))
    }

    // MARK: - ModelState Helpers

    func testModelStateIsDownloaded() {
        var state = ModelState()
        XCTAssertFalse(state.isDownloaded(.qwen3ASR06B6bit), "Not yet downloaded")
        state.downloadedEngines.insert(STTEngine.qwen3ASR06B6bit.rawValue)
        XCTAssertTrue(state.isDownloaded(.qwen3ASR06B6bit), "After insert, must be downloaded")
    }

    func testModelStatePhaseHelper() {
        var state = ModelState()
        XCTAssertEqual(state.phase(for: .qwen3ASR06B6bit), .idle, "Default phase is idle")
        state.downloadPhases[STTEngine.qwen3ASR06B6bit.rawValue] = .downloading
        XCTAssertEqual(state.phase(for: .qwen3ASR06B6bit), .downloading)
    }

    func testModelStateProgressHelper() {
        var state = ModelState()
        XCTAssertEqual(state.progress(for: .qwen3ASR06B6bit), 0.0, "Default progress is 0")
        state.downloadProgress[STTEngine.qwen3ASR06B6bit.rawValue] = 0.5
        XCTAssertEqual(state.progress(for: .qwen3ASR06B6bit), 0.5)
    }

    func testModelStateReset() {
        var state = ModelState()
        state.downloadedEngines.insert(STTEngine.qwen3ASR06B6bit.rawValue)
        state.downloadPhases[STTEngine.qwen3ASR06B6bit.rawValue] = .completed
        state.downloadProgress[STTEngine.qwen3ASR06B6bit.rawValue] = 1.0
        state.downloadSpeed[STTEngine.qwen3ASR06B6bit.rawValue] = "5 MB/s"

        state.resetDownloadState(for: .qwen3ASR06B6bit)

        XCTAssertEqual(state.phase(for: .qwen3ASR06B6bit), .idle, "After reset, phase must be idle")
        XCTAssertEqual(state.progress(for: .qwen3ASR06B6bit), 0, "After reset, progress must be 0")
        XCTAssertTrue(state.speed(for: .qwen3ASR06B6bit).isEmpty, "After reset, speed must be empty")
        // downloadedEngines should NOT be cleared by resetDownloadState
        XCTAssertTrue(state.isDownloaded(.qwen3ASR06B6bit), "resetDownloadState must not clear downloadedEngines")
    }
}
