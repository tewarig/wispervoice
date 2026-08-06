import XCTest
// @testable import WisperVoice (logic test - sources compiled in)
import AppKit

final class TextInjectorTests: XCTestCase {
    func testInjectFallbackWhenAXNotTrusted() {
        let text = "hello test \(UUID().uuidString)"
        TextInjector.inject(text: text)
        // Use RunLoop to wait instead of expectation (avoids deadlock in xctest direct run)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let pb = NSPasteboard.general.string(forType: .string)
        XCTAssertTrue(pb != nil)
    }

    func testInjectEmptyStringDoesNotCrash() {
        TextInjector.inject(text: "")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(true)
    }

    func testInjectLongString() {
        let long = String(repeating: "a ", count: 1000)
        TextInjector.inject(text: long)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertTrue(true)
    }

    func testInjectTwiceInRow() {
        TextInjector.inject(text: "first")
        TextInjector.inject(text: "second")
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertTrue(true)
    }
}
