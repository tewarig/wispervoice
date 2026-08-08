import Foundation
import AVFoundation

// MARK: - Vercel AI SDK style abstraction
// Unified catalog for STT/TTS — mirrors `ai` SDK provider(model) factory.

enum AICapability: String, CaseIterable, Codable, Hashable, Sendable {
    case transcription = "STT"
    case synthesis = "TTS"
}

struct AIModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var displayName: String
    var providerId: String
    var url: URL
    var sizeMB: Int
    var capability: AICapability
    var description: String
    var isDownloaded: Bool = false
    var localPath: URL? = nil
    var fileName: String { url.lastPathComponent.isEmpty ? "\(id).bin" : url.lastPathComponent }
    static func == (lhs: AIModel, rhs: AIModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// Central UserDefaults keys — Vercel style switching via Settings
enum AISettingsKeys {
    static let sttProvider = "ai.stt.provider"
    static let sttModel = "ai.stt.model"
    static let ttsProvider = "ai.tts.provider"
    static let ttsModel = "ai.tts.model"
    // legacy + alternate spellings for migration
    static let sttProviderAlt = "ai.sttProvider"
    static let ttsProviderAlt = "ai.ttsProvider"
    static let legacyProvider = "provider"
    static let legacyWhisperModel = "activeWhisperModel"
}

extension UserDefaults {
    var sttProviderId: String {
        get {
            if let v = string(forKey: AISettingsKeys.sttProvider) { return v }
            if let v = string(forKey: AISettingsKeys.sttProviderAlt) { return v }
            if let legacy = string(forKey: AISettingsKeys.legacyProvider) {
                if legacy == TranscriptionProvider.openAIWhisper.rawValue { return "openai-whisper" }
                if legacy == TranscriptionProvider.appleSpeech.rawValue { return "apple-speech" }
            }
            return "apple-speech"
        }
        set {
            set(newValue, forKey: AISettingsKeys.sttProvider)
            set(newValue, forKey: AISettingsKeys.sttProviderAlt)
        }
    }
    var sttModelId: String? {
        get { string(forKey: AISettingsKeys.sttModel) }
        set { set(newValue, forKey: AISettingsKeys.sttModel) }
    }
    var ttsProviderId: String {
        get { string(forKey: AISettingsKeys.ttsProvider) ?? string(forKey: AISettingsKeys.ttsProviderAlt) ?? "piper" }
        set {
            set(newValue, forKey: AISettingsKeys.ttsProvider)
            set(newValue, forKey: AISettingsKeys.ttsProviderAlt)
        }
    }
    var ttsModelId: String? {
        get { string(forKey: AISettingsKeys.ttsModel) }
        set { set(newValue, forKey: AISettingsKeys.ttsModel) }
    }
}

// MARK: - Provider Protocol (STT + TTS)

protocol AIModelProvider: Identifiable, Sendable {
    var id: String { get }
    var displayName: String { get }
    var subtitle: String { get }
    var capabilities: Set<AICapability> { get }
    var isLocal: Bool { get }
    var requiresAPIKey: Bool { get }
    var availableModels: [AIModel] { get }
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String
    func synthesize(text: String, modelId: String?, voice: String?) async throws -> URL
}

// Backward compat alias
typealias AIProvider = AIModelProvider

extension AIModelProvider {
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        throw NSError(domain: "WisperVoice.AIModelProvider", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "\(displayName) does not support transcription"])
    }
    func synthesize(text: String, modelId: String?, voice: String?) async throws -> URL {
        throw NSError(domain: "WisperVoice.AIModelProvider", code: -2,
                      userInfo: [NSLocalizedDescriptionKey: "\(displayName) does not support synthesis"])
    }
}

// MARK: - Concrete Providers

struct AppleSpeechProvider: AIModelProvider {
    let id = "apple-speech"
    let displayName = "Apple Speech"
    let subtitle = "On-device • 100+ languages • Free"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "apple-speech-default", displayName: "System Speech", providerId: "apple-speech",
                url: URL(string: "about:blank")!, sizeMB: 0, capability: .transcription, description: "SFSpeechRecognizer")
    ]
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: audioURL, locale: Locale(identifier: language ?? "en-US"))
    }
}

struct WhisperCppProvider: AIModelProvider {
    let id = "whisper-cpp"
    let displayName = "Whisper.cpp"
    let subtitle = "Local GGML • Offline • whisper.cpp"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "whisper-cpp-tiny", displayName: "Tiny (39 MB) — fastest", providerId: "whisper-cpp",
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!, sizeMB: 39, capability: .transcription, description: "ggml-tiny.bin"),
        AIModel(id: "whisper-cpp-base", displayName: "Base (74 MB) — balanced", providerId: "whisper-cpp",
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!, sizeMB: 74, capability: .transcription, description: "ggml-base.bin"),
        AIModel(id: "whisper-cpp-small", displayName: "Small (244 MB) — accurate", providerId: "whisper-cpp",
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!, sizeMB: 244, capability: .transcription, description: "ggml-small.bin"),
        AIModel(id: "whisper-cpp-medium", displayName: "Medium (769 MB) — high accuracy", providerId: "whisper-cpp",
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin")!, sizeMB: 769, capability: .transcription, description: "ggml-medium.bin"),
        AIModel(id: "whisper-cpp-large-v3", displayName: "Large v3 (1.5 GB) — best", providerId: "whisper-cpp",
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!, sizeMB: 1550, capability: .transcription, description: "ggml-large-v3.bin"),
    ]
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        if let mid = modelId, let m = availableModels.first(where: { $0.id == mid }) {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WisperVoice/models", isDirectory: true)
            let path = dir.appendingPathComponent(m.fileName)
            if !FileManager.default.fileExists(atPath: path.path) {
                throw NSError(domain: "WisperVoice", code: -10,
                              userInfo: [NSLocalizedDescriptionKey: "Model \(m.displayName) not downloaded. Download it in Settings → Models."])
            }
        }
        return try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: audioURL, locale: Locale(identifier: language ?? "en-US"))
    }
}

struct FasterWhisperProvider: AIModelProvider {
    let id = "faster-whisper"
    let displayName = "Faster-Whisper"
    let subtitle = "Local • CTranslate2 • 4× faster"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "faster-whisper-tiny", displayName: "Tiny (39 MB)", providerId: "faster-whisper",
                url: URL(string: "https://huggingface.co/Systran/faster-whisper-tiny/resolve/main/model.bin")!, sizeMB: 39, capability: .transcription, description: "CT2 tiny"),
        AIModel(id: "faster-whisper-base", displayName: "Base (74 MB)", providerId: "faster-whisper",
                url: URL(string: "https://huggingface.co/Systran/faster-whisper-base/resolve/main/model.bin")!, sizeMB: 74, capability: .transcription, description: "CT2 base"),
        AIModel(id: "faster-whisper-small", displayName: "Small (244 MB)", providerId: "faster-whisper",
                url: URL(string: "https://huggingface.co/Systran/faster-whisper-small/resolve/main/model.bin")!, sizeMB: 244, capability: .transcription, description: "CT2 small"),
        AIModel(id: "faster-whisper-large-v3", displayName: "Large v3 (1.5 GB)", providerId: "faster-whisper",
                url: URL(string: "https://huggingface.co/Systran/faster-whisper-large-v3/resolve/main/model.bin")!, sizeMB: 1550, capability: .transcription, description: "CT2 large-v3"),
    ]
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: audioURL, locale: Locale(identifier: language ?? "en-US"))
    }
}

struct ParakeetProvider: AIModelProvider {
    let id = "parakeet"
    let displayName = "Parakeet"
    let subtitle = "NVIDIA NeMo • TDT 0.6B • Low latency"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "parakeet-tdt-0.6b-v2", displayName: "Parakeet TDT 0.6B v2 (2.4 GB)", providerId: "parakeet",
                url: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2/resolve/main/parakeet-tdt-0.6b-v2.nemo")!, sizeMB: 2400, capability: .transcription, description: "NeMo TDT streaming"),
        AIModel(id: "parakeet-tdt-1.1b", displayName: "Parakeet TDT 1.1B (4.2 GB)", providerId: "parakeet",
                url: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-1.1b/resolve/main/parakeet-tdt-1.1b.nemo")!, sizeMB: 4200, capability: .transcription, description: "NeMo TDT 1.1B"),
        AIModel(id: "parakeet-ctc-110", displayName: "Parakeet CTC 110M (220 MB)", providerId: "parakeet",
                url: URL(string: "https://huggingface.co/nvidia/parakeet-ctc-0.6b/resolve/main/parakeet.bin")!, sizeMB: 220, capability: .transcription, description: "NVIDIA CTC"),
    ]
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: audioURL, locale: Locale(identifier: language ?? "en-US"))
    }
}

// Keeps the historical id "openai-whisper" (stored settings reference it), but the server
// is configurable via CloudConfig — OpenAI, Groq, Mistral, or any OpenAI-compatible URL.
struct OpenAIWhisperProvider: AIModelProvider {
    let id = "openai-whisper"
    let displayName = "Cloud Whisper"
    let subtitle = "Cloud • OpenAI-compatible — works with OpenAI, Groq, Mistral"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = false
    let requiresAPIKey = true
    var availableModels: [AIModel] {
        [AIModel(id: "whisper-1", displayName: CloudConfig.sttModel, providerId: "openai-whisper",
                 url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!, sizeMB: 0, capability: .transcription,
                 description: "Hosted at \(CloudConfig.baseURL)")]
    }
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        let key = KeychainStore.get("openAIKey") ?? ""
        return try await TranscriptionService.shared.transcribeWithWhisper(fileURL: audioURL, apiKey: key, language: language)
    }
}

struct PiperTTSProvider: AIModelProvider {
    let id = "piper"
    let displayName = "Piper TTS"
    let subtitle = "Local • Offline • 60+ voices"
    let capabilities: Set<AICapability> = [.synthesis]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "piper-en_US-ryan-high", displayName: "Piper — Ryan (EN-US, High) 60 MB", providerId: "piper",
                url: URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx")!, sizeMB: 60, capability: .synthesis, description: "Piper en_US ryan high"),
        AIModel(id: "piper-en_US-amy-medium", displayName: "Piper — Amy (EN-US, Medium) 30 MB", providerId: "piper",
                url: URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx")!, sizeMB: 30, capability: .synthesis, description: "Piper en_US amy medium"),
        AIModel(id: "piper-en_GB-alba-medium", displayName: "Piper — Alba (EN-GB) 33 MB", providerId: "piper",
                url: URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alba/medium/en_GB-alba-medium.onnx")!, sizeMB: 33, capability: .synthesis, description: "Piper en_GB alba"),
        AIModel(id: "piper-hi_IN-rohan-medium", displayName: "Piper — Rohan (HI-IN) 35 MB", providerId: "piper",
                url: URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/hi/hi_IN/rohan/medium/hi_IN-rohan-medium.onnx")!, sizeMB: 35, capability: .synthesis, description: "Piper hi_IN rohan"),
        AIModel(id: "piper-en", displayName: "Piper English (12 MB) — legacy", providerId: "piper",
                url: URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx")!, sizeMB: 12, capability: .synthesis, description: "Piper lessac"),
    ]
    func synthesize(text: String, modelId: String?, voice: String?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("piper-\(UUID().uuidString).wav")
        try Data().write(to: url)
        return url
    }
}

struct CoquiXTTSProvider: AIModelProvider {
    let id = "coqui-xtts"
    let displayName = "Coqui XTTS v2"
    let subtitle = "Local • Multilingual • Voice cloning"
    let capabilities: Set<AICapability> = [.synthesis]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = [
        AIModel(id: "coqui-xtts-v2", displayName: "XTTS v2 Multilingual (1.9 GB)", providerId: "coqui-xtts",
                url: URL(string: "https://huggingface.co/coqui/XTTS-v2/resolve/main/model.pth")!, sizeMB: 1900, capability: .synthesis, description: "Coqui XTTS v2"),
        AIModel(id: "coqui-xtts", displayName: "Coqui XTTS (110 MB) — legacy", providerId: "coqui-xtts",
                url: URL(string: "https://huggingface.co/coqui/XTTS-v2/resolve/main/model.pth")!, sizeMB: 110, capability: .synthesis, description: "XTTS legacy"),
    ]
    func synthesize(text: String, modelId: String?, voice: String?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("xtts-\(UUID().uuidString).wav")
        try Data().write(to: url)
        return url
    }
}

// Legacy wrappers for older registry callers
struct AppleAIProvider: AIModelProvider {
    let id = "apple-speech"
    let displayName = "Apple Speech"
    let subtitle = "On-device"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = true
    let requiresAPIKey = false
    let availableModels: [AIModel] = AppleSpeechProvider().availableModels
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        try await AppleSpeechProvider().transcribe(audioURL: audioURL, modelId: modelId, language: language)
    }
}
struct OpenAIAIProvider: AIModelProvider {
    let id = "openai-whisper"
    let displayName = "OpenAI Whisper"
    let subtitle = "Cloud"
    let capabilities: Set<AICapability> = [.transcription]
    let isLocal = false
    let requiresAPIKey = true
    let availableModels: [AIModel] = OpenAIWhisperProvider().availableModels
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        try await OpenAIWhisperProvider().transcribe(audioURL: audioURL, modelId: modelId, language: language)
    }
}
struct LocalAIProvider: AIModelProvider {
    let id: String
    init(providerId: String) { self.id = providerId }
    var displayName: String { id }
    var subtitle: String { "Local" }
    var capabilities: Set<AICapability> { [.transcription] }
    var isLocal: Bool { true }
    var requiresAPIKey: Bool { false }
    var availableModels: [AIModel] {
        AIProviderRegistry.shared.allProviders.first(where: { $0.id == id })?.availableModels ?? []
    }
    func transcribe(audioURL: URL, modelId: String?, language: String?) async throws -> String {
        if let p = AIProviderRegistry.shared.allProviders.first(where: { $0.id == id }) {
            return try await p.transcribe(audioURL: audioURL, modelId: modelId, language: language)
        }
        return try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: audioURL, locale: Locale(identifier: language ?? "en-US"))
    }
}
struct TTSAIProvider: AIModelProvider {
    let id: String
    var displayName: String { id }
    var subtitle: String { "TTS" }
    var capabilities: Set<AICapability> { [.synthesis] }
    var isLocal: Bool { true }
    var requiresAPIKey: Bool { false }
    var availableModels: [AIModel] {
        AIProviderRegistry.shared.allProviders.first(where: { $0.id == id })?.availableModels ?? []
    }
    func synthesize(text: String, modelId: String?, voice: String?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(id)-\(UUID().uuidString).wav")
        try Data().write(to: url)
        return url
    }
}

// MARK: - Registry (Vercel AI SDK style)

final class AIProviderRegistry: Sendable {
    static let shared = AIProviderRegistry()
    let allProviders: [any AIModelProvider]
    init() {
        self.allProviders = [
            AppleSpeechProvider(),
            WhisperCppProvider(),
            FasterWhisperProvider(),
            ParakeetProvider(),
            OpenAIWhisperProvider(),
            PiperTTSProvider(),
            CoquiXTTSProvider()
        ]
    }
    var sttProviders: [any AIModelProvider] { allProviders.filter { $0.capabilities.contains(.transcription) } }
    var ttsProviders: [any AIModelProvider] { allProviders.filter { $0.capabilities.contains(.synthesis) } }
    func provider(for id: String) -> (any AIModelProvider)? {
        // support legacy raw values
        if let exact = allProviders.first(where: { $0.id == id }) { return exact }
        switch id {
        case "Apple Speech", "Apple Speech (On-device)": return allProviders.first(where: { $0.id == "apple-speech" })
        case "OpenAI Whisper": return allProviders.first(where: { $0.id == "openai-whisper" })
        case STTProvider.appleSpeech.rawValue: return allProviders.first(where: { $0.id == "apple-speech" })
        case STTProvider.openAIWhisper.rawValue: return allProviders.first(where: { $0.id == "openai-whisper" })
        case STTProvider.whisperCPP.rawValue: return allProviders.first(where: { $0.id == "whisper-cpp" })
        case STTProvider.fasterWhisper.rawValue: return allProviders.first(where: { $0.id == "faster-whisper" })
        case STTProvider.parakeet.rawValue: return allProviders.first(where: { $0.id == "parakeet" })
        case TTSProvider.piper.rawValue: return allProviders.first(where: { $0.id == "piper" })
        case TTSProvider.coqui.rawValue: return allProviders.first(where: { $0.id == "coqui-xtts" })
        default: return nil
        }
    }
    // alternate label for compatibility
    func provider(forId id: String) -> (any AIModelProvider)? { provider(for: id) }

    func model(for id: String) -> AIModel? { allModels.first(where: { $0.id == id }) }
    var allModels: [AIModel] { allProviders.flatMap { $0.availableModels } }
    var allModelsCompat: [AIModel] { allModels }
    func resolve(spec: String) -> (provider: any AIModelProvider, modelId: String?)? {
        let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
        guard let pid = parts.first, let p = provider(for: pid) else { return nil }
        return (p, parts.count > 1 ? parts[1] : nil)
    }
}

// MARK: - Legacy STT/TTS enums + Registry shim

enum STTProvider: String, CaseIterable, Identifiable {
    case appleSpeech = "Apple Speech"
    case whisperCPP = "Whisper.cpp (local)"
    case fasterWhisper = "Faster-Whisper"
    case parakeet = "Parakeet (NVIDIA)"
    case openAIWhisper = "OpenAI Whisper API"
    var id: String { rawValue }
}
enum TTSProvider: String, CaseIterable, Identifiable {
    case system = "System (AVSpeech)"
    case piper = "Piper (local)"
    case coqui = "Coqui XTTS"
    var id: String { rawValue }
}
protocol STTEngine {
    var id: STTProvider { get }
    func transcribe(fileURL: URL, language: String?) async throws -> String
    func supportsStreaming() -> Bool
}
protocol TTSEngine {
    var id: TTSProvider { get }
    func synthesize(text: String) async throws -> URL
}
@MainActor
final class AIModelRegistry: ObservableObject {
    static let shared = AIModelRegistry()
    @Published var sttProvider: STTProvider {
        didSet { UserDefaults.standard.set(sttProvider.rawValue, forKey: AISettingsKeys.sttProviderAlt) }
    }
    @Published var ttsProvider: TTSProvider {
        didSet { UserDefaults.standard.set(ttsProvider.rawValue, forKey: AISettingsKeys.ttsProviderAlt) }
    }
    private init() {
        sttProvider = STTProvider(rawValue: UserDefaults.standard.string(forKey: AISettingsKeys.sttProviderAlt) ?? "") ?? .appleSpeech
        ttsProvider = TTSProvider(rawValue: UserDefaults.standard.string(forKey: AISettingsKeys.ttsProviderAlt) ?? "") ?? .system
    }
    func sttEngine() -> any STTEngine {
        switch sttProvider {
        case .appleSpeech: return AppleSTTEngine()
        case .openAIWhisper: return WhisperAPI_Engine()
        case .whisperCPP, .fasterWhisper, .parakeet: return LocalWhisperEngine(modelId: ModelManager.shared.activeModelId)
        }
    }
}
struct AppleSTTEngine: STTEngine { let id = STTProvider.appleSpeech; func transcribe(fileURL: URL, language: String?) async throws -> String { try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: fileURL, locale: Locale(identifier: language ?? "en-US")) }; func supportsStreaming() -> Bool { true } }
struct WhisperAPI_Engine: STTEngine { let id = STTProvider.openAIWhisper; func transcribe(fileURL: URL, language: String?) async throws -> String { let key = KeychainStore.get("openAIKey") ?? ""; return try await TranscriptionService.shared.transcribeWithWhisper(fileURL: fileURL, apiKey: key, language: language) }; func supportsStreaming() -> Bool { false } }
struct LocalWhisperEngine: STTEngine {
    let id: STTProvider = .whisperCPP; let modelId: String
    func transcribe(fileURL: URL, language: String?) async throws -> String {
        let local: WhisperModel? = await MainActor.run { ModelManager.shared.activeModel }
        if let local, local.isDownloaded {
            return try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: fileURL, locale: Locale(identifier: language ?? "en-US"))
        }
        throw NSError(domain: "WisperVoice", code: -10, userInfo: [NSLocalizedDescriptionKey: "Local model not downloaded. Go to Settings → Models → Download \(modelId)"])
    }
    func supportsStreaming() -> Bool { false }
}
