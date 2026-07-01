import XCTest
import CoreGraphics
import Carbon
@testable import LocalVoice

// MARK: - HotkeyMonitor Tests

/// Tests for the HotkeyMonitor and related keycode constants.
/// These tests verify the static logic (constants, flag checks) without
/// needing actual CGEventTap or Accessibility permissions.
final class HotkeyMonitorTests: XCTestCase {

    // MARK: - Fn Keycode Constant

    func testFnKeyCodeConstant() {
        XCTAssertEqual(UInt32.fnKey, 0x3F, "Fn/Globe key code must be 0x3F")
    }

    // MARK: - Navigation Keycode Constants

    func testRightCommandKeyCode() {
        XCTAssertEqual(UInt32.rightCommand, 0x36, "Right Command key code must be 0x36")
    }

    func testLeftOptionKeyCode() {
        XCTAssertEqual(UInt32.leftOption, 0x3A, "Left Option key code must be 0x3A")
    }

    func testRightOptionKeyCode() {
        XCTAssertEqual(UInt32.rightOption, 0x3D, "Right Option key code must be 0x3D")
    }

    func testLeftCommandKeyCode() {
        XCTAssertEqual(UInt32.leftCommand, 0x37, "Left Command key code must be 0x37")
    }

    func testCapsLockKeyCode() {
        XCTAssertEqual(UInt32.capsLock, 0x39, "Caps Lock key code must be 0x39")
    }

    func testAllNavigationKeycodesAreDistinct() {
        let keycodes: Set<UInt32> = [
            UInt32.fnKey,
            UInt32.rightCommand,
            UInt32.leftOption,
            UInt32.rightOption,
            UInt32.leftCommand,
            UInt32.capsLock,
        ]
        XCTAssertEqual(keycodes.count, 6, "All keycode constants must be distinct")
    }

    // MARK: - maskSecondaryFn Flag Logic

    func testMaskSecondaryFnFlagExists() {
        // Verify that maskSecondaryFn is a valid, non-empty flag
        let flags: CGEventFlags = .maskSecondaryFn
        XCTAssertTrue(flags.contains(.maskSecondaryFn), "maskSecondaryFn must be a valid CGEventFlags value")
        XCTAssertFalse(flags.isEmpty, "maskSecondaryFn must not be empty")
    }

    func testMaskSecondaryFnFlagRawValue() {
        // The raw value should match the documented IOHID value
        // kCGEventFlagMaskSecondaryFn = 1 << 23 = 0x800000
        XCTAssertEqual(CGEventFlags.maskSecondaryFn.rawValue, 0x00800000,
                       "maskSecondaryFn must have raw value 0x00800000")
    }

    func testFnPressedLogicWithOnlySecondaryFn() {
        // Simulate: flags only contains .maskSecondaryFn → Fn is pressed
        let flags: CGEventFlags = .maskSecondaryFn
        let fnPressed = flags.contains(.maskSecondaryFn)
        XCTAssertTrue(fnPressed, "When flags contain maskSecondaryFn, Fn is considered pressed")
    }

    func testFnPressedLogicWithMultipleFlags() {
        // Simulate: flags contains .maskSecondaryFn + .maskCommand → Fn is still pressed
        let flags: CGEventFlags = [.maskSecondaryFn, .maskCommand]
        let fnPressed = flags.contains(.maskSecondaryFn)
        XCTAssertTrue(fnPressed, "Fn press should be detectable even when other modifiers are held")
    }

    func testFnNotPressedWithoutSecondaryFn() {
        // Simulate: flags without maskSecondaryFn → Fn is not pressed
        let flags: CGEventFlags = .maskCommand
        let fnPressed = flags.contains(.maskSecondaryFn)
        XCTAssertFalse(fnPressed, "Without maskSecondaryFn, Fn is not pressed")
    }

    func testFnNotPressedWithEmptyFlags() {
        let flags: CGEventFlags = []
        let fnPressed = flags.contains(.maskSecondaryFn)
        XCTAssertFalse(fnPressed, "Without any flags, Fn is not pressed")
    }

    // MARK: - HotkeyBinding Keycode Consistency

    func testHotkeyBindingFnKeyMatchesConstant() {
        XCTAssertEqual(HotkeyBinding.fnKey.keyCode, UInt32.fnKey,
                       "HotkeyBinding.fnKey.keyCode must match UInt32.fnKey")
    }

    func testHotkeyBindingRightCommandMatchesConstant() {
        XCTAssertEqual(HotkeyBinding.rightCommand.keyCode, UInt32.rightCommand,
                       "HotkeyBinding.rightCommand.keyCode must match UInt32.rightCommand")
    }

    func testHotkeyBindingLeftOptionMatchesConstant() {
        XCTAssertEqual(HotkeyBinding.leftOption.keyCode, UInt32.leftOption,
                       "HotkeyBinding.leftOption.keyCode must match UInt32.leftOption")
    }
}
