import AppKit
import AVFoundation
import Speech
import ApplicationServices
import SwiftUI

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var micGranted: Bool = false
    @Published var speechGranted: Bool = false
    @Published var accessibilityGranted: Bool = false

    private var pollTimer: Timer?

    init() {
        refresh()
        // Accessibility has no change notification, so poll while anything is outstanding.
        // Without this the app reports "not granted" forever after you flip the switch in
        // System Settings, because refresh() would only ever run once at launch.
        startPolling()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshFromNotification),
            name: NSApplication.didBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshFromNotification),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    deinit {
        pollTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func refreshFromNotification() {
        DispatchQueue.main.async { self.refresh() }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func refresh() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        let ax = AXIsProcessTrusted()
        // Only publish on change — this runs every 1.5s and would otherwise thrash SwiftUI.
        if mic != micGranted { micGranted = mic }
        if speech != speechGranted { speechGranted = speech }
        if ax != accessibilityGranted { accessibilityGranted = ax }
        // Everything granted: stop the timer, keep the activation observers as a safety net
        // in case a permission is revoked while we are in the background.
        if allGranted { pollTimer?.invalidate(); pollTimer = nil }
        else if pollTimer == nil { startPolling() }
    }

    static func checkAll() {
        // Trigger AX prompt if needed
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    /// Launch-time variant: prompt only when the user has never been asked. Never opens
    /// System Settings — the launch path calling the button variant below meant EVERY
    /// start of the app yanked System Settings open for users who had already granted.
    static func requestMicrophonePermissionAtLaunch() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }

    /// Button variant (permissions banner "Enable"): the user explicitly asked, so when
    /// the system prompt can't fire again, send them to the pane instead of doing nothing.
    static func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default:
            openSystemSettings(pane: "Privacy_Microphone")
        }
    }

    func requestSpeechPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in
                DispatchQueue.main.async { self.refresh() }
            }
        default:
            Self.openSystemSettings(pane: "Privacy_SpeechRecognition")
        }
    }

    func requestAccessibility() {
        // First click: let the system consent dialog do its job alone. Opening the pane
        // in the same tick raced the dialog — System Settings activated over and hid it.
        let alreadyPrompted = UserDefaults.standard.bool(forKey: "axPromptedOnce")
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        UserDefaults.standard.set(true, forKey: "axPromptedOnce")
        // Poll for grant
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refresh() }
        if !trusted && alreadyPrompted {
            Self.openSystemSettings(pane: "Privacy_Accessibility")
        }
    }

    private static func openSystemSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Cloud Whisper is the ONLY engine that never touches SFSpeechRecognizer — the local
    /// whisper.cpp / faster-whisper / parakeet providers currently delegate file
    /// transcription to Apple Speech, so they need the permission too (exempting them
    /// meant a surprise system prompt mid-transcription while the UI showed all-granted).
    /// Resolved via the shared legacy-aware accessor so this always agrees with
    /// DictationManager.usesAppleSpeech.
    static var speechRequired: Bool {
        UserDefaults.standard.sttProviderId != "openai-whisper"
    }

    var allGranted: Bool { micGranted && accessibilityGranted && (speechGranted || !Self.speechRequired) }
}
