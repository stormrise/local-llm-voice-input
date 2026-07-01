import XCTest
@testable import LocalVoice

// MARK: - RecordingState Tests

/// Tests for the RecordingState enum and its state transitions.
final class RecordingStateTests: XCTestCase {

    // MARK: - State Transitions

    func testIdleToRecording() {
        let state: RecordingState = .idle
        let recording = RecordingState.recording(RecordingInfo(startTime: Date()))
        XCTAssertNotEqual(state, recording, "idle ≠ recording")
    }

    func testRecordingToTranscribing() {
        let info = RecordingInfo(startTime: Date())
        let recording: RecordingState = .recording(info)
        let transcribing: RecordingState = .transcribing
        XCTAssertNotEqual(recording, transcribing, "recording ≠ transcribing")
    }

    func testTranscribingToComplete() {
        let transcribing: RecordingState = .transcribing
        let complete: RecordingState = .complete("hello world")
        XCTAssertNotEqual(transcribing, complete, "transcribing ≠ complete")
    }

    func testCompleteToIdle() {
        let complete: RecordingState = .complete("hello")
        let idle: RecordingState = .idle
        XCTAssertNotEqual(complete, idle, "complete ≠ idle")
    }

    func testRecordingToFailed() {
        let info = RecordingInfo(startTime: Date())
        let recording: RecordingState = .recording(info)
        let failed: RecordingState = .failed("mic not available")
        XCTAssertNotEqual(recording, failed, "recording ≠ failed")
    }

    // MARK: - isRecording Property

    func testIsRecordingTrueOnlyForRecording() {
        let info = RecordingInfo(startTime: Date())
        XCTAssertTrue(RecordingState.recording(info).isRecording, "isRecording must be true for .recording")
    }

    func testIsRecordingFalseForIdle() {
        XCTAssertFalse(RecordingState.idle.isRecording)
    }

    func testIsRecordingFalseForTranscribing() {
        XCTAssertFalse(RecordingState.transcribing.isRecording)
    }

    func testIsRecordingFalseForComplete() {
        XCTAssertFalse(RecordingState.complete("text").isRecording)
    }

    func testIsRecordingFalseForFailed() {
        XCTAssertFalse(RecordingState.failed("error").isRecording)
    }

    // MARK: - statusText

    func testStatusTextIdle() {
        XCTAssertEqual(RecordingState.idle.statusText, "Ready")
    }

    func testStatusTextTranscribing() {
        XCTAssertEqual(RecordingState.transcribing.statusText, "Transcribing...")
    }

    func testStatusTextComplete() {
        XCTAssertEqual(RecordingState.complete("hello").statusText, "Done")
    }

    func testStatusTextFailed() {
        XCTAssertEqual(RecordingState.failed("error msg").statusText, "error msg")
    }

    // MARK: - Equatable Conformance

    func testIdleEquality() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
    }

    func testTranscribingEquality() {
        XCTAssertEqual(RecordingState.transcribing, RecordingState.transcribing)
    }

    func testCompleteEquality() {
        XCTAssertEqual(RecordingState.complete("hello"), RecordingState.complete("hello"))
    }

    func testCompleteInequality() {
        XCTAssertNotEqual(RecordingState.complete("hello"), RecordingState.complete("world"))
    }

    func testFailedEquality() {
        XCTAssertEqual(RecordingState.failed("err"), RecordingState.failed("err"))
    }

    func testFailedInequality() {
        XCTAssertNotEqual(RecordingState.failed("err1"), RecordingState.failed("err2"))
    }

    func testRecordingEquality() {
        let now = Date()
        let info1 = RecordingInfo(startTime: now)
        let info2 = RecordingInfo(startTime: now)
        XCTAssertEqual(RecordingState.recording(info1), RecordingState.recording(info2))
    }

    // MARK: - RecordingInfo

    func testRecordingInfoDurationFormatted() {
        let startTime = Date()
        let info = RecordingInfo(startTime: startTime)
        // Duration is 0 at creation
        XCTAssertEqual(info.durationFormatted, "0:00")
    }
}
