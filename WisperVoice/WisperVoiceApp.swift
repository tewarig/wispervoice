import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement

@main
struct WisperVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dictationManager = DictationManager()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var modelManager = ModelManager.shared

    var body: some Scene {
        // Always-visible menu bar (Apple HIG: .window style + persistent label)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dictationManager)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
        } label: {
            Label("WisperVoice", systemImage: iconName)
                .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.window)

        // Main window — opens via menu bar "Open WisperVoice"
        Window("WisperVoice", id: "main") {
            ContentView()
                .environmentObject(dictationManager)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 420)

        Settings {
            SettingsView()
                .environmentObject(dictationManager)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
        }
    }

    private var iconName: String {
        switch dictationManager.state {
        case .idle: return "waveform"
        case .recording: return "waveform.badge.mic"
        case .transcribing: return "waveform.badge.ellipsis"
        case .injecting: return "checkmark.circle"
        }
    }
}

// Dashboard + walkthrough
struct ContentView: View {
    @EnvironmentObject var dictation: DictationManager
    @EnvironmentObject var permissions: PermissionsManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var showClipboard = false
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("WisperVoice").font(.largeTitle.weight(.semibold))
            Text("Speak in any app — Option+Space or Fn×2")
                .font(.callout).foregroundStyle(.secondary)
            Button(dictation.state == .recording ? "Stop Recording" : "Start Dictating") {
                dictation.toggleDictation()
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.space, modifiers: .option)
            HStack(spacing: 10) {
                SettingsLink { Label("Open Settings", systemImage: "gearshape") }.buttonStyle(.bordered).controlSize(.regular)
                Button { showClipboard = true } label: { Label("Clipboard History", systemImage: "clock.arrow.circlepath") }.buttonStyle(.bordered).controlSize(.regular)
            }
            Button("Show Walkthrough") { showOnboarding = true }.font(.caption).buttonStyle(.borderless)
            if !permissions.allGranted {
                Text("Grant Microphone / Accessibility in Settings to enable everywhere.")
                    .font(.caption2).foregroundStyle(Theme.alert).multilineTextAlignment(.center)
            }
            if !dictation.lastTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Last transcript").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(dictation.lastTranscript, forType: .string)
                        }.font(.caption).buttonStyle(.bordered).controlSize(.mini)
                        Button("Paste Again") { TextInjector.inject(text: dictation.lastTranscript) }.font(.caption).buttonStyle(.borderedProminent).controlSize(.mini)
                    }
                    Text(dictation.lastTranscript).font(Theme.transcript).padding(8).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled).lineLimit(4)
                }.padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showOnboarding) { OnboardingView(isPresented: $showOnboarding) }
        .sheet(isPresented: $showClipboard) { ClipboardHistoryView().frame(width: 560, height: 460) }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular) // Show in Dock so user can open
        NSApp.activate(ignoringOtherApps: false)
        // Ensure overlay singleton is created early
        _ = OverlayWindow.sharedInstance
        // Start tracking the frontmost app from launch so the first dictation has a paste target
        _ = FocusTracker.shared
        // Fallback NSStatusItem so icon never disappears (MenuBarExtra may hide on some configs / Bartender)
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WisperVoice")
            img?.isTemplate = true
            statusItem?.button?.image = img
            statusItem?.button?.action = #selector(openMain)
            statusItem?.button?.target = self
            statusItem?.button?.toolTip = "WisperVoice — Option+Space to dictate"
            statusItem?.menu = makeStatusMenu()
        }
        // Re-ensure after wake / activation (Chrome fullscreen, Bartender)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(ensureStatusItem), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(ensureStatusItem), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ensureStatusItem), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ensureStatusItem), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Also check 1s after launch in case MenuBarExtra failed to attach
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { self.ensureStatusItem() }
        FocusLog.log("launch: axTrusted=\(AXIsProcessTrusted()) build=\(Bundle.main.bundleIdentifier ?? "?")")
        PermissionsManager.checkAll()
        PermissionsManager.requestMicrophonePermission()
        // Auto-register for startup if user enabled before
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            try? SMAppService.mainApp.register()
        }
    }

    @objc func openMain() {
        NSApp.activate(ignoringOtherApps: true)
        // Try main window first — force to active Space and above Chrome
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            // Also bring pill to front if recording
            if OverlayWindow.sharedInstance.isVisible { OverlayWindow.sharedInstance.orderFrontRegardless() }
            return
        }
        // Try SwiftUI openWindow
        NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
        // Ensure at least Settings opens
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
            if NSApp.keyWindow == nil {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            // Ensure main window when it appears is on active Space
            if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                w.orderFrontRegardless()
            }
        }
    }
    @objc func openSettings() { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func ensureStatusItem() {
        if statusItem == nil || statusItem?.button == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WisperVoice")
            img?.isTemplate = true
            statusItem?.button?.image = img
            statusItem?.button?.action = #selector(openMain)
            statusItem?.button?.target = self
        }
    }
    private func makeStatusMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(NSMenuItem(title: "Open WisperVoice", action: #selector(openMain), keyEquivalent: ""))
        m.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Quit WisperVoice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        m.items.forEach { $0.target = self === $0.target ? self : $0.target }
        // Fixup targets
        m.items[0].target = self; m.items[1].target = self; m.items[3].target = NSApp
        return m
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMain(); return true
    }
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? { makeStatusMenu() }
}
