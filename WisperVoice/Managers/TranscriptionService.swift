import Foundation
import Speech
import AVFoundation
import Security

/// API keys live in the macOS Keychain — encrypted at rest, unlocked with the user's login.
/// They previously sat in UserDefaults, which is a PLAINTEXT plist on disk; `migrate()`
/// moves any legacy value across once and deletes the plaintext copy.
/// Uses the native Security framework — no third-party dependency needed for this.
enum KeychainStore {
    /// Fixed service name — deliberately NOT Bundle.main.bundleIdentifier, which differs
    /// in the test runner and would fragment stored keys.
    private static let service = "com.wispervoice.dev"

    /// Unit tests exercise DictationManager.openAIKey, whose didSet writes here. With the
    /// fixed service name that would overwrite — and on the empty-string assignment DELETE —
    /// the developer's real key from the login Keychain. Tests get an in-memory store.
    private static let isTestRun = NSClassFromString("XCTestCase") != nil
    private static var testStore: [String: String] = [:]

    static func set(_ value: String, account: String) {
        if isTestRun {
            if value.isEmpty { testStore.removeValue(forKey: account) } else { testStore[account] = value }
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        guard !value.isEmpty else { SecItemDelete(query as CFDictionary); return }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = Data(value.utf8)
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(_ account: String) -> String? {
        if isTestRun { return testStore[account] }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// One-time move of a legacy plaintext UserDefaults value into the Keychain.
    /// The plaintext copy is ALWAYS deleted when found — even when the Keychain already
    /// holds a key — otherwise the plaintext lingers and defeats the point of the move.
    static func migrate(defaultsKey: String, account: String) {
        guard let legacy = UserDefaults.standard.string(forKey: defaultsKey), !legacy.isEmpty else { return }
        if get(account) == nil { set(legacy, account: account) }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case appleSpeech = "Apple Speech (On-device)"
    case openAIWhisper = "OpenAI Whisper"
    var id: String { rawValue }

    /// Map to unified AIModelProvider id
    var aiProviderId: String {
        switch self {
        case .appleSpeech: return "apple-speech"
        case .openAIWhisper: return "openai-whisper"
        }
    }
}

/// Result of probing an API key against the provider before any transcription is attempted.
enum APIKeyCheck: Equatable {
    case valid
    case invalid
    case unreachable
}

/// The cloud engine speaks the OpenAI wire format, but the SERVER is user-configurable —
/// Groq (~9× cheaper Whisper) and Mistral Voxtral are drop-in compatible, as are local
/// OpenAI-compatible servers. Unset defaults fall back to OpenAI itself.
enum CloudConfig {
    static let baseURLKey = "cloud.baseURL"
    static let sttModelKey = "cloud.sttModel"
    static let polishModelKey = "cloud.polishModel"

    static var baseURL: String {
        let stored = UserDefaults.standard.string(forKey: baseURLKey) ?? ""
        return stored.isEmpty ? "https://api.openai.com/v1" : stored
    }
    static var sttModel: String {
        let stored = UserDefaults.standard.string(forKey: sttModelKey) ?? ""
        return stored.isEmpty ? "whisper-1" : stored
    }
    static var polishModel: String {
        let stored = UserDefaults.standard.string(forKey: polishModelKey) ?? ""
        return stored.isEmpty ? "gpt-4o-mini" : stored
    }
    /// Base URL + API path, tolerating a trailing slash in the stored base.
    static func endpoint(_ path: String) -> URL? {
        var base = baseURL
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + path)
    }
}

final class TranscriptionService {
    static let shared = TranscriptionService()
    var urlSession: URLSession = .shared
    init(urlSession: URLSession = .shared) { self.urlSession = urlSession }

    /// Cheap authenticated GET — 200 means the key works, 401/403 means it doesn't.
    /// Anything else (offline, timeout) is reported as unreachable rather than invalid so
    /// a network blip never tells the user their key is wrong.
    func validateOpenAIKey(_ key: String) async -> APIKeyCheck {
        guard !key.isEmpty, let url = CloudConfig.endpoint("/models") else { return .invalid }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        guard let (_, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        switch http.statusCode {
        case 200: return .valid
        case 401, 403: return .invalid
        default: return .unreachable
        }
    }

    // MARK: - Apple Speech (SFSpeechRecognizer) — free, on-device/cloud, supports 100+ languages
    func transcribeWithAppleSpeech(fileURL: URL, locale: Locale = Locale(identifier: "en-US")) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "WisperVoice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for \(locale.identifier)"])
        }

        // Ensure auth
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            let status = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
            }
            guard status == .authorized else {
                throw NSError(domain: "WisperVoice", code: -3, userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"])
            }
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error { cont.resume(throwing: error); return }
                if let result, result.isFinal {
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    // MARK: - Cloud transcription (OpenAI-compatible: OpenAI, Groq, Mistral, custom)
    func transcribeWithWhisper(fileURL: URL, apiKey: String, language: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "WisperVoice", code: -4, userInfo: [NSLocalizedDescriptionKey: "API key not set. Add it in Settings."])
        }
        guard let endpoint = CloudConfig.endpoint("/audio/transcriptions") else {
            throw NSError(domain: "WisperVoice", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL — check it in Settings."])
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }

        // model
        append("--\(boundary)\r\n"); append("Content-Disposition: form-data; name=\"model\"\r\n\r\n"); append("\(CloudConfig.sttModel)\r\n")
        if let lang = language, !lang.isEmpty {
            append("--\(boundary)\r\n"); append("Content-Disposition: form-data; name=\"language\"\r\n\r\n"); append("\(lang)\r\n")
        }
        // file
        let data = try Data(contentsOf: fileURL)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        req.httpBody = body

        let (respData, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: respData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "WisperVoice", code: -5, userInfo: [NSLocalizedDescriptionKey: "Whisper API error: \(msg)"])
        }
        struct WhisperResp: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(WhisperResp.self, from: respData)
        return decoded.text
    }

    // MARK: - Auto-edit / polish (like Wispr Flow's auto-edits)
    /// Lightweight local cleanup: filler words, capitalisation, punctuation spacing.
    /// If OpenAI key is set and `useLLMPolishing` is true, an LLM polish pass is done.
    func polish(_ raw: String, useLLMPolishing: Bool, openAIKey: String?) async -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        // 1) Remove filler words (whole-word, case-insensitive)
        let fillers = [" um ", " uh ", " like ", " you know ", " so ", " actually ", " basically ", " literally "]
        // pad for edge matching
        var padded = " " + text + " "
        for f in fillers {
            padded = padded.replacingOccurrences(of: f, with: " ", options: .caseInsensitive)
        }
        // also leading/trailing fillers
        for filler in ["um ", "uh ", "like "] {
            if padded.lowercased().hasPrefix(" " + filler) {
                padded = String(padded.dropFirst(filler.count + 1))
                padded = " " + padded
            }
        }
        text = padded.trimmingCharacters(in: .whitespacesAndNewlines)
        // collapse double spaces
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        // 2) Capitalize first letter of sentences
        text = text.prefix(1).uppercased() + text.dropFirst()
        // 3) Ensure sentence punctuation
        if let last = text.last, !".!?".contains(last) {
            // don't add period if looks like a fragment that is a question? keep simple
        }

        // 4) Optional LLM polish (GPT-4o-mini)
        if useLLMPolishing, let key = openAIKey, !key.isEmpty {
            if let polished = try? await llmPolish(text, apiKey: key) {
                return polished
            }
        }
        return text
    }

    /// Grammar/cleanup pass — same configurable OpenAI-compatible server and key as
    /// transcription, so cheap chat models (Groq Llama, Mistral small, a local server)
    /// work as drop-ins for the default gpt-4o-mini.
    func llmPolish(_ text: String, apiKey: String) async throws -> String {
        guard let endpoint = CloudConfig.endpoint("/chat/completions") else {
            throw NSError(domain: "WisperVoice", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL — check it in Settings."])
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let sys = "You are a dictation formatter. Fix grammar, punctuation, capitalization. Remove filler words (um, uh). Keep the speaker's voice and language. Preserve Hinglish/mixed-language if present. Return ONLY the cleaned text, no quotes, no explanation."
        let body: [String: Any] = [
            "model": CloudConfig.polishModel,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": sys],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NSError(domain: "WisperVoice", code: -6, userInfo: nil) }
        struct ChatResp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResp.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }

    // MARK: - Vercel AI SDK style unified dispatch

    /// Unified transcribe entry point — mirrors `generateText({ model: provider('model') })`.
    /// Resolves provider via AIProviderRegistry and falls back to legacy paths.
    func transcribe(fileURL: URL, providerId: String, modelId: String?, language: String?, apiKey: String?) async throws -> String {
        // Update apiKey if supplied via provider that needs it
        if let key = apiKey, !key.isEmpty {
            // store for the cloud provider to read — Keychain, never UserDefaults
            KeychainStore.set(key, account: "openAIKey")
        }
        if let provider = AIProviderRegistry.shared.provider(for: providerId) {
            return try await provider.transcribe(audioURL: fileURL, modelId: modelId, language: language)
        }
        // Fallback to legacy switch
        switch providerId {
        case "apple-speech", TranscriptionProvider.appleSpeech.rawValue:
            return try await transcribeWithAppleSpeech(fileURL: fileURL, locale: Locale(identifier: language ?? "en-US"))
        case "openai-whisper", TranscriptionProvider.openAIWhisper.rawValue, "whisper-1":
            let key = apiKey ?? KeychainStore.get("openAIKey") ?? ""
            return try await transcribeWithWhisper(fileURL: fileURL, apiKey: key, language: language)
        default:
            throw NSError(domain: "WisperVoice", code: -7, userInfo: [NSLocalizedDescriptionKey: "Unknown provider: \(providerId)"])
        }
    }

    /// Unified TTS synthesis — returns audio file URL (stub until engine bundled).
    func synthesize(text: String, providerId: String, modelId: String?, voice: String?) async throws -> URL {
        if let provider = AIProviderRegistry.shared.provider(for: providerId) {
            return try await provider.synthesize(text: text, modelId: modelId, voice: voice)
        }
        throw NSError(domain: "WisperVoice", code: -8, userInfo: [NSLocalizedDescriptionKey: "Unknown TTS provider: \(providerId)"])
    }
}
