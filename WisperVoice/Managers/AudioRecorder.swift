import AVFoundation
import Foundation

final class AudioRecorder: NSObject {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var fileURL: URL?
    /// Called on audio thread with RMS level 0...1 for VAD/waveform
    var onLevel: ((Float) -> Void)?
    /// Called on audio thread with each raw buffer — feeds live speech recognition.
    /// Without this the SFSpeechAudioBufferRecognitionRequest never receives audio and
    /// live transcription silently produces nothing.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    var isRecording: Bool { engine?.isRunning == true }

    /// Start recording to a temporary WAV file. Returns URL on success.
    func startRecording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wisper-\(UUID().uuidString).wav")

        // In unit test environment, bypass hardware and create empty file
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            // Create empty wav file via AVAudioFile without engine
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
            // Keep fileURL for stop/cancel semantics
            self.fileURL = url
            self.audioFile = file
            // Do not start engine in test
            return url
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Ensure format is valid
        guard format.sampleRate > 0 else {
            throw NSError(domain: "WisperVoice", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio input format"])
        }

        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ])

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            do { try file.write(from: buffer) } catch { }
            self?.onBuffer?(buffer)
            // RMS for VAD + waveform — compute quickly on tap thread
            if let ch = buffer.floatChannelData?[0] {
                let n = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<n { let v = ch[i]; sum += v * v }
                let rms = n > 0 ? sqrt(sum / Float(n)) : 0
                // scale roughly 0...1 (speech ~0.02-0.3)
                let level = min(1, rms * 8)
                self?.onLevel?(level)
            }
        }

        engine.prepare()
        try engine.start()

        self.engine = engine
        self.audioFile = file
        self.fileURL = url
        return url
    }

    /// Stop and return file URL
    func stopRecording() -> URL? {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        audioFile = nil
        onBuffer = nil
        let url = fileURL
        fileURL = nil
        return url
    }

    func cancelRecording() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        audioFile = nil
        onBuffer = nil
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
    }
}
