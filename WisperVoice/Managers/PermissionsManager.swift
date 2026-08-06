import AppKit
import AVFoundation
import Speech
import ApplicationServices
import SwiftUI

final class PermissionsManager: ObservableObject {
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

    static func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default: break
        }
    }

    func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { self.refresh() }
        }
    }

    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        // Poll for grant
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refresh() }
    }

    var allGranted: Bool { micGranted && speechGranted && accessibilityGranted }
}
