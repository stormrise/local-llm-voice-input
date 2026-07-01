import XCTest
import Cocoa
@testable import LocalVoice

// MARK: - TextInjector Tests

/// Tests for the TextInjector class.
/// These tests focus on pure logic (PasteboardItem data model) and
/// non-permission-dependent paths. Tests involving NSPasteboard or
/// AX APIs may be skipped in CI environments.
@MainActor
final class TextInjectorTests: XCTestCase {

    // MARK: - PasteboardItem Tests

    func testPasteboardItemStoresTypes() {
        let types: [NSPasteboard.PasteboardType: Data] = [
            .string: "Hello".data(using: .utf8)!,
            .rtf: Data([0x01, 0x02, 0x03]),
        ]
        let item = PasteboardItem(types: types)
        XCTAssertEqual(item.types.count, 2, "PasteboardItem should store all type-data pairs")
        XCTAssertEqual(item.types[.string], "Hello".data(using: .utf8)!)
        XCTAssertEqual(item.types[.rtf], Data([0x01, 0x02, 0x03]))
    }

    func testPasteboardItemEmptyTypes() {
        let item = PasteboardItem(types: [:])
        XCTAssertTrue(item.types.isEmpty, "PasteboardItem should support empty types")
    }

    func testPasteboardItemMultipleStringTypes() {
        let plainText = "Plain text"
        let htmlText = "<b>HTML</b>"
        let types: [NSPasteboard.PasteboardType: Data] = [
            .string: plainText.data(using: .utf8)!,
            .html: htmlText.data(using: .utf8)!,
            .rtf: Data([0x00]),
        ]
        let item = PasteboardItem(types: types)
        XCTAssertEqual(item.types.count, 3)
        XCTAssertEqual(String(data: item.types[.string]!, encoding: .utf8), plainText)
        XCTAssertEqual(String(data: item.types[.html]!, encoding: .utf8), htmlText)
    }

    func testPasteboardItemDataIntegrity() {
        // Verify binary data survives round-trip through the dictionary
        let binaryData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF])
        let types: [NSPasteboard.PasteboardType: Data] = [
            NSPasteboard.PasteboardType("public.data"): binaryData,
        ]
        let item = PasteboardItem(types: types)
        XCTAssertEqual(item.types[NSPasteboard.PasteboardType("public.data")], binaryData)
    }

    // MARK: - Save/Restore Pasteboard Tests

    func testSavePasteboardReturnsArray() {
        let injector = TextInjector()
        let items = injector.savePasteboard()
        // savePasteboard() should always return an array (possibly empty)
        XCTAssertNotNil(items, "savePasteboard() must return an array")
    }

    func testSaveThenRestorePasteboardDoesNotCrash() {
        let injector = TextInjector()
        let savedItems = injector.savePasteboard()

        // Modify pasteboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("tmp_test", forType: .string)

        // Restore — must not crash
        injector.restorePasteboard(savedItems)
    }

    func testRestoreWithEmptyArrayDoesNotCrash() {
        let injector = TextInjector()
        // Passing an empty array should be a no-op
        injector.restorePasteboard([])
    }

}
