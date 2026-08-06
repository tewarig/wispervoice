import Foundation
import AVFoundation
import SwiftUI

struct TTSModel: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var url: URL
    var sizeMB: Int
    var isDownloaded: Bool = false
}

@MainActor
final class TTSManager: ObservableObject {
    static let shared = TTSManager()
    @Published var models: [TTSModel] = [
        TTSModel(id: "piper-en", displayName: "Piper — English (12 MB)", url: URL(string:"https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx")!, sizeMB: 12),
        TTSModel(id: "coqui-xtts", displayName: "Coqui XTTS (110 MB)", url: URL(string:"https://huggingface.co/coqui/XTTS-v2/resolve/main/model.pth")!, sizeMB: 110),
    ]
    @Published var activeId = UserDefaults.standard.string(forKey:"tts.active") ?? "system"
    @Published var downloading: String? = nil
    @Published var progress: [String:Double] = [:]

    private var dir: URL {
        let d = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("WisperVoice/tts", isDirectory:true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    func refresh() {
        for i in models.indices {
            let p = dir.appendingPathComponent(models[i].id+".bin")
            models[i].isDownloaded = FileManager.default.fileExists(atPath: p.path)
        }
    }
    func download(_ m: TTSModel) {
        guard downloading==nil else { return }
        downloading=m.id; progress[m.id]=0
        let dest = dir.appendingPathComponent(m.id+".bin")
        let task = URLSession.shared.downloadTask(with: m.url) { [weak self] tmp,_,_ in
            Task { @MainActor in
                if let tmp { try? FileManager.default.moveItem(at: tmp, to: dest); self?.refresh() }
                self?.downloading=nil
            }
        }
        task.resume()
    }
}
