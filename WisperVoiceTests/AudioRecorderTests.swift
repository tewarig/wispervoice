import XCTest
// @testable import WisperVoice (logic test - sources compiled in)

final class AudioRecorderTests: XCTestCase {
    func testInitialIsNotRecording() {
        let rec = AudioRecorder()
        XCTAssertFalse(rec.isRecording)
    }

    func testStopWhenNotRecordingReturnsNil() {
        let rec = AudioRecorder()
        XCTAssertNil(rec.stopRecording())
    }

    func testCancelWhenNotRecordingDoesNotCrash() {
        let rec = AudioRecorder()
        rec.cancelRecording()
        XCTAssertFalse(rec.isRecording)
        XCTAssertNil(rec.stopRecording())
    }

    func testCancelAfterStopNoCrash() {
        let rec = AudioRecorder()
        // Without hardware, start may throw; test cancel path after failed start
        do { _ = try rec.startRecording() } catch { /* expected on CI without mic */ }
        rec.cancelRecording()
        XCTAssertFalse(rec.isRecording)
    }

    func testStartRecordingThrowsWithoutValidFormatOrGrantsInvalidURL() {
        // On headless CI, inputNode format may be invalid or engine start fails.
        // We test that throwing or succeeding both are handled, and stop returns URL or nil
        let rec = AudioRecorder()
        do {
            let url = try rec.startRecording()
            XCTAssertTrue(url.path.contains("wisper-"))
            XCTAssertTrue(url.path.hasSuffix(".wav"))
            // stop should return same url
            let stopped = rec.stopRecording()
            XCTAssertEqual(stopped, url)
            XCTAssertFalse(rec.isRecording)
            // cleanup
            try? FileManager.default.removeItem(at: url)
        } catch {
            // Acceptable on CI without audio hardware
            XCTAssertFalse(rec.isRecording)
        }
    }

    func testDoubleCancelSafe() {
        let rec = AudioRecorder()
        rec.cancelRecording()
        rec.cancelRecording()
        XCTAssertNil(rec.stopRecording())
    }
}
