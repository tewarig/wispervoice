import Foundation
import Speech
import AVFoundation

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

final class TranscriptionService {
    static let shared = TranscriptionService()
    var urlSession: URLSession = .shared
    init(urlSession: URLSession = .shared) { self.urlSession = urlSession }

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

    // MARK: - OpenAI Whisper API
    func transcribeWithWhisper(fileURL: URL, apiKey: String, language: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "WisperVoice", code: -4, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set. Add it in Settings."])
        }

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }

        // model
        append("--\(boundary)\r\n"); append("Content-Disposition: form-data; name=\"model\"\r\n\r\n"); append("whisper-1\r\n")
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

    func llmPolish(_ text: String, apiKey: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let sys = "You are a dictation formatter. Fix grammar, punctuation, capitalization. Remove filler words (um, uh). Keep the speaker's voice and language. Preserve Hinglish/mixed-language if present. Return ONLY the cleaned text, no quotes, no explanation."
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
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
            // store transiently for OpenAI provider to read from UserDefaults
            UserDefaults.standard.set(key, forKey: "openAIKey")
        }
        if let provider = AIProviderRegistry.shared.provider(for: providerId) {
            return try await provider.transcribe(audioURL: fileURL, modelId: modelId, language: language)
        }
        // Fallback to legacy switch
        switch providerId {
        case "apple-speech", TranscriptionProvider.appleSpeech.rawValue:
            return try await transcribeWithAppleSpeech(fileURL: fileURL, locale: Locale(identifier: language ?? "en-US"))
        case "openai-whisper", TranscriptionProvider.openAIWhisper.rawValue, "whisper-1":
            let key = apiKey ?? UserDefaults.standard.string(forKey: "openAIKey") ?? ""
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
