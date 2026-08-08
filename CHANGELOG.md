# Changelog

All notable changes to WisperVoice are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

Releases are cut by pushing a `vX.Y.Z` tag — see `plan/RELEASE.md` for the playbook.

## [0.1.0] — 2026-08-08

First public release.

### Added
- System-wide dictation: press ⌥ Space (or one of 8 shortcut presets, or Fn×2)
  in any app; the transcript is typed at your cursor.
- Live transcription pill with audio-reactive waveform, head-truncated live
  text, six screen positions, and copy fallback when insertion isn't possible.
- Live typing: pause briefly mid-dictation and the words so far are typed
  immediately (Apple Speech engine).
- Engines: Apple Speech (on-device, live preview), local Whisper models
  (whisper.cpp), and OpenAI-compatible cloud transcription with configurable
  server/model — Groq and Mistral presets included.
- Live API key verification against the configured server.
- One-window app: Dictate, Models, History (searchable), Settings, About.
- Onboarding with engine choice, shortcut selection, and permission setup.
- Menu bar popover with dictate control, recent transcripts, and build label.
- History with per-dictation duration; usage stats (dictations, words, minutes).
- Optional AI grammar polish with configurable model.

### Security
- API keys are stored in the macOS Keychain (never in plaintext preferences).

### Known limitations
- Release builds are not yet notarized: after installing, run
  `xattr -d com.apple.quarantine /Applications/WisperVoice.app` once.
- Live transcript preview is Apple-Speech-only; other engines transcribe when
  you stop.
- Text-to-speech is a preview; voice downloads reserve model slots only.
