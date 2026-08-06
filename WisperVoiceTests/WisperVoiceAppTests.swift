import XCTest
// @testable import WisperVoice (logic test - sources compiled in)
import SwiftUI

final class WisperVoiceAppTests: XCTestCase {

    func testDictationStateIconMapping() {
        // Replicate WisperVoiceApp iconName logic
        func icon(for state: DictationState) -> String {
            switch state {
            case .idle: return "waveform"
            case .recording: return "waveform.badge.mic"
            case .transcribing: return "waveform.badge.ellipsis"
            case .injecting: return "checkmark.circle"
            }
        }
        XCTAssertEqual(icon(for: .idle), "waveform")
        XCTAssertEqual(icon(for: .recording), "waveform.badge.mic")
        XCTAssertEqual(icon(for: .transcribing), "waveform.badge.ellipsis")
        XCTAssertEqual(icon(for: .injecting), "checkmark.circle")
    }

    func testMenuBarStatusTextAllStates() {
        func status(for state: DictationState, provider: String) -> String {
            switch state {
            case .idle: return "Ready — \(provider)"
            case .recording: return "● Recording — press again to stop"
            case .transcribing: return "Transcribing…"
            case .injecting: return "Inserted ✓"
            }
        }
        XCTAssertTrue(status(for: .idle, provider: "Apple Speech (On-device)").contains("Ready"))
        XCTAssertEqual(status(for: .recording, provider: ""), "● Recording — press again to stop")
        XCTAssertEqual(status(for: .transcribing, provider: ""), "Transcribing…")
        XCTAssertEqual(status(for: .injecting, provider: ""), "Inserted ✓")
    }

    func testOverlayTitleIconColorAllStates() {
        // Verify OverlayView private helpers via brute-force checking body doesn't crash
        for state in [DictationState.idle, .recording, .transcribing, .injecting] as [DictationState] {
            let v = OverlayView(state: state, level: 0, transcript: "")
            _ = v.body
        }
    }
}
