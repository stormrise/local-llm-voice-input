import XCTest
@testable import LocalVoice

// MARK: - PermissionChecker Tests

/// Tests for PermissionStatus enum values and PermissionSummary logic.
/// These tests are purely about the enum types and do NOT check actual
/// system permissions (which require user interaction / special entitlements).
final class PermissionCheckerTests: XCTestCase {

    // MARK: - PermissionStatus Enum

    func testPermissionStatusAllCases() {
        XCTAssertEqual(PermissionStatus.unknown, PermissionStatus.unknown)
        XCTAssertEqual(PermissionStatus.granted, PermissionStatus.granted)
        XCTAssertEqual(PermissionStatus.denied, PermissionStatus.denied)
        XCTAssertEqual(PermissionStatus.restricted, PermissionStatus.restricted)
    }

    func testPermissionStatusEquality() {
        XCTAssertEqual(PermissionStatus.unknown, .unknown)
        XCTAssertEqual(PermissionStatus.granted, .granted)
        XCTAssertEqual(PermissionStatus.denied, .denied)
        XCTAssertEqual(PermissionStatus.restricted, .restricted)
        XCTAssertNotEqual(PermissionStatus.granted, .denied)
        XCTAssertNotEqual(PermissionStatus.unknown, .granted)
    }

    // MARK: - PermissionStatus Properties

    func testPermissionStatusIcons() {
        XCTAssertEqual(PermissionStatus.unknown.icon, "questionmark.circle")
        XCTAssertEqual(PermissionStatus.granted.icon, "checkmark.circle.fill")
        XCTAssertEqual(PermissionStatus.denied.icon, "xmark.circle.fill")
        XCTAssertEqual(PermissionStatus.restricted.icon, "lock.circle.fill")
    }

    func testPermissionStatusStatusText() {
        XCTAssertEqual(PermissionStatus.unknown.statusText, "Not checked")
        XCTAssertEqual(PermissionStatus.granted.statusText, "Granted")
        XCTAssertEqual(PermissionStatus.denied.statusText, "Denied")
        XCTAssertEqual(PermissionStatus.restricted.statusText, "Restricted")
    }

    // MARK: - PermissionSummary

    func testPermissionSummaryAllGranted() {
        let summary = PermissionSummary(
            microphone: .granted,
            accessibility: .granted,
            inputMonitoring: .granted
        )
        XCTAssertTrue(summary.allGranted, "All granted → allGranted must be true")
    }

    func testPermissionSummaryMicrophoneDenied() {
        let summary = PermissionSummary(
            microphone: .denied,
            accessibility: .granted,
            inputMonitoring: .granted
        )
        XCTAssertFalse(summary.allGranted, "Any denied → allGranted must be false")
    }

    func testPermissionSummaryAccessibilityDenied() {
        let summary = PermissionSummary(
            microphone: .granted,
            accessibility: .denied,
            inputMonitoring: .granted
        )
        XCTAssertFalse(summary.allGranted, "Any denied → allGranted must be false")
    }

    func testPermissionSummaryAllDenied() {
        let summary = PermissionSummary(
            microphone: .denied,
            accessibility: .denied,
            inputMonitoring: .denied
        )
        XCTAssertFalse(summary.allGranted)
    }

    // MARK: - PermissionState

    func testPermissionStateAllGranted() {
        var state = PermissionState()
        state.microphone = .granted
        state.accessibility = .granted
        XCTAssertTrue(state.allGranted)
    }

    func testPermissionStateMissingPermissions() {
        var state = PermissionState()
        state.microphone = .denied
        state.accessibility = .granted
        let missing = state.missingPermissions
        XCTAssertTrue(missing.contains("Microphone"))
        XCTAssertFalse(missing.contains("Accessibility"))
        XCTAssertEqual(missing.count, 1)
    }

    func testPermissionStateAllMissing() {
        var state = PermissionState()
        state.microphone = .denied
        state.accessibility = .denied
        let missing = state.missingPermissions
        XCTAssertEqual(missing.count, 2)
        XCTAssertTrue(missing.contains("Microphone"))
        XCTAssertTrue(missing.contains("Accessibility"))
    }

    func testPermissionStateNoMissingWhenGranted() {
        var state = PermissionState()
        state.microphone = .granted
        state.accessibility = .granted
        XCTAssertTrue(state.missingPermissions.isEmpty)
    }
}
