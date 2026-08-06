# Memory — WisperVoice
- Stack: SwiftUI MenuBarExtra + AVAudioEngine + SFSpeech + Whisper API + AX/CGEvent + ServiceManagement
- Pill: OverlayWindow.sharedInstance singleton, liveTranscript via SFSpeechAudioBufferRequest, close ×, capsule glass
- Models: ModelManager (ggml) + AIModelProvider (7 providers, Vercel style) + TTSManager (Piper/Coqui stub)
- Tests: WisperVoiceTests logic bundle, 9 suites, BUILD/TEST SUCCEEDED, xcodebuild test blocked by IOPMAssertion in sandbox
- Website: website/ Vite+React+Tailwind, dist built
- Always update AGENTS.md after changes
