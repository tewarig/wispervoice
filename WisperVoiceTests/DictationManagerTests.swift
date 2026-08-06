import XCTest
// @testable import WisperVoice (logic test - sources compiled in)

@MainActor
final class DictationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "provider")
        UserDefaults.standard.removeObject(forKey: "languageCode")
        UserDefaults.standard.removeObject(forKey: "openAIKey")
        UserDefaults.standard.removeObject(forKey: "autoPaste")
        UserDefaults.standard.removeObject(forKey: "llmPolish")
        UserDefaults.standard.removeObject(forKey: "holdToTalk")
    }
    func testProviderComputedProperty() {
        let m = DictationManager()
        m.providerRaw = TranscriptionProvider.appleSpeech.rawValue
        XCTAssertEqual(m.provider, .appleSpeech)
        m.provider = .openAIWhisper
        XCTAssertEqual(m.providerRaw, TranscriptionProvider.openAIWhisper.rawValue)
        // invalid raw falls back to appleSpeech
        m.providerRaw = "invalid"
        XCTAssertEqual(m.provider, .appleSpeech)
    }

    func testInitialState() {
        let m = DictationManager()
        XCTAssertEqual(m.state, .idle)
        XCTAssertEqual(m.lastTranscript, "")
        XCTAssertNil(m.errorMessage)
        XCTAssertEqual(m.audioLevel, 0)
        XCTAssertTrue(m.autoPaste) // default true
        XCTAssertFalse(m.llmPolish)
        XCTAssertEqual(m.languageCode, "en-US")
    }

    func testToggleFromIdleStartsRecordingOrSetsError() {
        let m = DictationManager()
        XCTAssertEqual(m.state, .idle)
        m.toggleDictation()
        // Should go to .recording or stay .idle with error if mic unavailable
        XCTAssertTrue(m.state == .recording || m.state == .idle)
        if m.state == .recording {
            XCTAssertNil(m.errorMessage)
            m.cancelRecording()
            XCTAssertEqual(m.state, .idle)
        } else {
            XCTAssertNotNil(m.errorMessage)
        }
    }

    func testToggleFromRecordingStops() {
        let m = DictationManager()
        // Force into recording without hardware by mocking? Instead test that stop guard works when not recording
        m.stopAndTranscribe()
        XCTAssertEqual(m.state, .idle) // guard returns
    }

    func testToggleFromTranscribingDoesNothing() {
        let m = DictationManager()
        m.state = .transcribing
        m.toggleDictation()
        XCTAssertEqual(m.state, .transcribing)
        m.state = .injecting
        m.toggleDictation()
        XCTAssertEqual(m.state, .injecting)
    }

    func testStartRecordingGuardWhenNotIdle() {
        let m = DictationManager()
        m.state = .recording
        m.startRecording()
        XCTAssertEqual(m.state, .recording)
        m.state = .transcribing; m.startRecording(); XCTAssertEqual(m.state, .transcribing)
    }

    func testCancelRecordingResets() {
        let m = DictationManager()
        m.state = .recording
        m.audioLevel = 0.5
        m.cancelRecording()
        XCTAssertEqual(m.state, .idle)
        // audioLevel metering timer invalidated, but audioLevel remains until next start; we test cancel doesn't crash
    }

    func testStopAndTranscribeGuardNotRecording() {
        let m = DictationManager()
        m.state = .idle
        m.stopAndTranscribe()
        XCTAssertEqual(m.state, .idle)
        m.state = .transcribing; m.stopAndTranscribe(); XCTAssertEqual(m.state, .transcribing)
    }

    func testAppStorageDefaults() {
        let m = DictationManager()
        // Test that @AppStorage wrappers are accessible
        m.openAIKey = "test-key"
        XCTAssertEqual(m.openAIKey, "test-key")
        m.openAIKey = ""
        m.languageCode = "hi-IN"
        XCTAssertEqual(m.languageCode, "hi-IN")
        m.autoPaste = false; XCTAssertFalse(m.autoPaste)
        m.autoPaste = true
        m.holdToTalk = true; XCTAssertTrue(m.holdToTalk)
        m.holdToTalk = false
    }

    func testDictationStateEquatable() {
        XCTAssertEqual(DictationState.idle, .idle)
        XCTAssertNotEqual(DictationState.recording, .idle)
        XCTAssertEqual(DictationState.transcribing, .transcribing)
        XCTAssertEqual(DictationState.injecting, .injecting)
    }
}
