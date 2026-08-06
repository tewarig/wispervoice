import Foundation
import SwiftUI
import Combine

struct WhisperModel: Identifiable, Codable, Equatable {
    var id: String // e.g. "whisper-base", "whisper-small" — legacy, maps to AIModel ids whisper-cpp-*
    var displayName: String
    var url: URL
    var sizeMB: Int
    var isDownloaded: Bool = false
    var localPath: URL? = nil

    /// Convert to unified AIModel
    var asAIModel: AIModel {
        AIModel(id: "whisper-cpp-\(id)", displayName: displayName, providerId: "whisper-cpp", url: url, sizeMB: sizeMB, capability: .transcription, description: url.lastPathComponent, isDownloaded: isDownloaded, localPath: localPath)
    }
}

@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    // Legacy whisper.cpp list (kept for backward compat + existing tests)
    @Published var models: [WhisperModel] = [
        WhisperModel(id: "tiny", displayName: "Tiny (39 MB) — fastest", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!, sizeMB: 39),
        WhisperModel(id: "base", displayName: "Base (74 MB) — balanced", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!, sizeMB: 74),
        WhisperModel(id: "small", displayName: "Small (244 MB) — accurate", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!, sizeMB: 244),
    ]
    @Published var activeModelId: String {
        didSet { UserDefaults.standard.set(activeModelId, forKey: "activeWhisperModel") }
    }

    // Vercel AI SDK style: provider + model switching via Settings
    @Published var selectedSTTProviderId: String {
        didSet { UserDefaults.standard.set(selectedSTTProviderId, forKey: AISettingsKeys.sttProvider) }
    }
    @Published var selectedSTTModelId: String? {
        didSet { UserDefaults.standard.set(selectedSTTModelId, forKey: AISettingsKeys.sttModel) }
    }
    @Published var selectedTTSProviderId: String {
        didSet { UserDefaults.standard.set(selectedTTSProviderId, forKey: AISettingsKeys.ttsProvider) }
    }
    @Published var selectedTTSModelId: String? {
        didSet { UserDefaults.standard.set(selectedTTSModelId, forKey: AISettingsKeys.ttsModel) }
    }

    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: String? = nil

    // Unified AIModel progress (same dict keyed by AIModel.id)
    @Published var aiDownloadProgress: [String: Double] = [:]
    @Published var aiDownloadingId: String? = nil

    private var modelsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WisperVoice/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var ttsModelsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WisperVoice/tts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        self.activeModelId = UserDefaults.standard.string(forKey: "activeWhisperModel") ?? "base"
        self.selectedSTTProviderId = UserDefaults.standard.string(forKey: AISettingsKeys.sttProvider) ?? UserDefaults.standard.sttProviderId
        self.selectedSTTModelId = UserDefaults.standard.string(forKey: AISettingsKeys.sttModel)
        self.selectedTTSProviderId = UserDefaults.standard.string(forKey: AISettingsKeys.ttsProvider) ?? "piper"
        self.selectedTTSModelId = UserDefaults.standard.string(forKey: AISettingsKeys.ttsModel)
        refreshDownloadedState()
        refreshAIDownloadedState()
    }

    func refreshDownloadedState() {
        for i in models.indices {
            let path = modelsDir.appendingPathComponent("ggml-\(models[i].id).bin")
            models[i].isDownloaded = FileManager.default.fileExists(atPath: path.path)
            models[i].localPath = models[i].isDownloaded ? path : nil
        }
    }

    var activeModel: WhisperModel? { models.first { $0.id == activeModelId } }

    func download(_ model: WhisperModel) {
        guard isDownloading == nil else { return }
        isDownloading = model.id
        downloadProgress[model.id] = 0
        let dest = modelsDir.appendingPathComponent("ggml-\(model.id).bin")
        let task = URLSession.shared.downloadTask(with: model.url) { [weak self] tempURL, resp, err in
            Task { @MainActor in
                defer { self?.isDownloading = nil }
                if let tempURL, err == nil {
                    try? FileManager.default.moveItem(at: tempURL, to: dest)
                    self?.refreshDownloadedState()
                    self?.refreshAIDownloadedState()
                    self?.downloadProgress[model.id] = 1
                } else {
                    self?.downloadProgress[model.id] = nil
                }
            }
        }
        // Progress via KVO
        let observer = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            Task { @MainActor in self?.downloadProgress[model.id] = p.fractionCompleted }
        }
        task.resume()
        // Keep observer alive briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { _ = observer }
    }

    func delete(_ model: WhisperModel) {
        guard let path = modelsDir.appendingPathComponent("ggml-\(model.id).bin") as URL? else { return }
        try? FileManager.default.removeItem(at: path)
        refreshDownloadedState()
        refreshAIDownloadedState()
        downloadProgress[model.id] = nil
    }

    func select(_ id: String) {
        activeModelId = id
        // keep unified selection in sync
        selectedSTTProviderId = "whisper-cpp"
        selectedSTTModelId = "whisper-cpp-\(id)"
    }

    // MARK: - Unified AIModel catalog

    var allAIModels: [AIModel] {
        AIProviderRegistry.shared.allModels.map { m in
            var copy = m
            let dir = m.capability == .synthesis ? ttsModelsDir : modelsDir
            let path = dir.appendingPathComponent(m.fileName)
            copy.isDownloaded = FileManager.default.fileExists(atPath: path.path)
            copy.localPath = copy.isDownloaded ? path : nil
            return copy
        }
    }

    var sttModels: [AIModel] { allAIModels.filter { $0.capability == .transcription } }
    var ttsModels: [AIModel] { allAIModels.filter { $0.capability == .synthesis } }

    func refreshAIDownloadedState() {
        // triggers objectWillChange via computed allAIModels; also keep legacy in sync
        objectWillChange.send()
    }

    // MARK: Unified provider/model selection

    func selectSTT(providerId: String, modelId: String?) {
        selectedSTTProviderId = providerId
        selectedSTTModelId = modelId
        // legacy shim for whisper-cpp
        if providerId == "whisper-cpp", let mid = modelId {
            let legacy = mid.replacingOccurrences(of: "whisper-cpp-", with: "")
            if models.contains(where: { $0.id == legacy }) { activeModelId = legacy }
        }
    }

    func selectTTS(providerId: String, modelId: String?) {
        selectedTTSProviderId = providerId
        selectedTTSModelId = modelId
    }

    // MARK: Generic AIModel download with stubbed progress for TTS (Piper/Coqui) and real download for STT

    func download(_ model: AIModel) {
        guard aiDownloadingId == nil else { return }
        aiDownloadingId = model.id
        aiDownloadProgress[model.id] = 0

        // For known small/local STT models we do real download; for large TTS we stub progress (user sees progress bar)
        let isStub = model.providerId == "piper" || model.providerId == "coqui-xtts"
        if isStub {
            // Stubbed download: simulate progress in steps then create empty file
            Task { @MainActor in
                for step in 1...10 {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    self.aiDownloadProgress[model.id] = Double(step) / 10.0
                }
                let dir = self.ttsModelsDir
                let dest = dir.appendingPathComponent(model.fileName)
                try? Data("stub-\(model.id)".utf8).write(to: dest)
                self.aiDownloadProgress[model.id] = 1
                self.aiDownloadingId = nil
                self.refreshAIDownloadedState()
            }
            return
        }

        let destDir = model.capability == .synthesis ? ttsModelsDir : modelsDir
        let dest = destDir.appendingPathComponent(model.fileName)
        let task = URLSession.shared.downloadTask(with: model.url) { [weak self] tempURL, _, err in
            Task { @MainActor in
                defer { self?.aiDownloadingId = nil }
                if let tempURL, err == nil {
                    try? FileManager.default.moveItem(at: tempURL, to: dest)
                    self?.aiDownloadProgress[model.id] = 1
                    self?.refreshAIDownloadedState()
                    self?.refreshDownloadedState()
                } else {
                    self?.aiDownloadProgress[model.id] = nil
                }
            }
        }
        let observer = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            Task { @MainActor in self?.aiDownloadProgress[model.id] = p.fractionCompleted }
        }
        task.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { _ = observer }
    }

    func delete(_ model: AIModel) {
        let dir = model.capability == .synthesis ? ttsModelsDir : modelsDir
        let path = dir.appendingPathComponent(model.fileName)
        try? FileManager.default.removeItem(at: path)
        aiDownloadProgress[model.id] = nil
        if aiDownloadingId == model.id { aiDownloadingId = nil }
        refreshAIDownloadedState()
        refreshDownloadedState()
    }

    func isAIDownloaded(_ model: AIModel) -> Bool {
        let dir = model.capability == .synthesis ? ttsModelsDir : modelsDir
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(model.fileName).path)
    }

    var modelsDirectoryPath: String { modelsDir.path }
    var ttsDirectoryPath: String { ttsModelsDir.path }
}
