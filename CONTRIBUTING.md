# Contributing to WisperVoice

Thanks for considering a contribution! WisperVoice aims to be the best open-source macOS dictation app — inspired by Wispr Flow — and every contribution helps.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). Be kind, be constructive.

## How to contribute

### 1. Find or file an issue

- Search [existing issues](../../issues) before opening a new one.
- For bugs, use the **Bug report** template. Include macOS version, Xcode version, steps to reproduce, and logs.
- For features, use the **Feature request** template. Explain the Wispr Flow parity or new capability you're proposing.
- Questions? Open a **Q&A** discussion or use the issue with label `question`.

### 2. Development setup

**Requirements:** macOS 14+, Xcode 16+, Swift 5.9+

```bash
git clone https://github.com/<you>/wisperVoice.git
cd wisperVoice
open WisperVoice.xcodeproj
# Select "My Mac" → Cmd+R
# Grant Microphone + Accessibility when prompted
```

**CLI build (sandbox-safe):**

```bash
xcodebuild -project WisperVoice.xcodeproj -scheme WisperVoice -configuration Debug \
  build -derivedDataPath /tmp/wisper_build

# Run tests with coverage
xcodebuild test -project WisperVoice.xcodeproj -scheme WisperVoice \
  -destination 'platform=macOS' -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO

# View coverage
xcrun xccov view --report TestResults.xcresult
```

**Local lint (optional):**

```bash
brew install swiftlint swiftformat
swiftlint lint
swiftformat --lint .
```

### 3. Branch & commit

- Fork the repo, create a feature branch: `git checkout -b feat/your-feature` or `fix/your-fix`.
- Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Keep PRs focused — one feature/fix per PR.
- Add or update tests for new behavior.

### 4. Pull request checklist

Before opening a PR:

- [ ] Tests pass locally (`xcodebuild test ...`)
- [ ] New code has tests; existing tests still pass
- [ ] `swiftlint` is clean (or justified warnings)
- [ ] Updated `README.md` / `plan/ROADMAP.md` if user-facing
- [ ] No Xcode source modifications beyond scope (PR template will prompt)

Use the [pull request template](.github/pull_request_template.md). Fill in all sections — it helps reviewers.

### 5. Review process

- A maintainer will review within a few days.
- CI must be green (build + test + coverage).
- Address feedback with follow-up commits; we squash on merge.

## Project structure

```
WisperVoice/
  WisperVoiceApp.swift          # @main, MenuBarExtra, AppDelegate
  Managers/
    DictationManager.swift      # @MainActor state machine
    AudioRecorder.swift         # AVAudioEngine → WAV
    TranscriptionService.swift  # Apple Speech + Whisper + polish()
    TextInjector.swift          # AX + clipboard CGEvent
    HotkeyManager.swift         # Carbon hotkey + Fn double-tap
    OverlayWindow.swift         # Floating pill
    PermissionsManager.swift    # Mic / Speech / AX
    ModelManager.swift          # Local Whisper models
    HistoryStore.swift          # UserDefaults JSON
  Views/
    MenuBarView.swift
    SettingsView.swift
  Resources/Assets.xcassets
WisperVoiceTests/               # XCTest suites
```

## Style guide

- Swift: follow Apple's [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Prefer `async/await` over callbacks; `@MainActor` for UI state.
- Keep managers testable — inject dependencies where practical, gate hardware with `NSClassFromString("XCTestCase")` only as last resort.
- Mark `// TODO:` with an issue link.

## Reporting security issues

Do **not** open a public issue. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
