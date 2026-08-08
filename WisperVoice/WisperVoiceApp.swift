import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement
import Combine

@main
struct WisperVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var dictationManager = DictationManager.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var modelManager = ModelManager.shared

    var body: some Scene {
        // No MenuBarExtra here: on this Mac (macOS 26) SwiftUI's MenuBarExtra never attaches
        // its NSStatusItem — the app owns zero windows in the menu bar row while "running"
        // (verified via CGWindowList). AppDelegate owns an explicit NSStatusItem + NSPopover
        // instead, which is what reliably worked historically.

        // Main window — opens via Dock icon or menu bar "Open App"
        Window("WisperVoice", id: "main") {
            ContentView()
                .environmentObject(dictationManager)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
        }
        .defaultSize(width: 1200, height: 800)
        // No Settings scene: settings is a sidebar section of the main window.
    }
}

// The whole app in ONE window: sidebar with every section (dictate, models, history,
// settings, about). There is deliberately no separate Settings window.
struct ContentView: View {
    enum AppSection: String, CaseIterable, Identifiable {
        case dictate, models, history, settings, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dictate: return "Dictate"
            case .models: return "Models"
            case .history: return "History"
            case .settings: return "Settings"
            case .about: return "About"
            }
        }
        var icon: String {
            switch self {
            case .dictate: return "waveform.and.mic"
            case .models: return "externaldrive"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }

    @EnvironmentObject var dictation: DictationManager
    @EnvironmentObject var permissions: PermissionsManager
    @ObservedObject private var history = HistoryStore.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    /// Persisted (not @State) so the menu bar popover / AppDelegate can deep-link a section
    /// before the window opens.
    @AppStorage("main.section") private var sectionRaw = AppSection.dictate.rawValue
    @State private var showOnboarding = false

    private var selection: Binding<AppSection?> {
        Binding(get: { AppSection(rawValue: sectionRaw) ?? .dictate },
                set: { sectionRaw = ($0 ?? .dictate).rawValue })
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: selection) { s in
                Label(s.title, systemImage: s.icon)
                    .padding(.vertical, 3)
                    .tag(s)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            switch AppSection(rawValue: sectionRaw) ?? .dictate {
            case .dictate: dashboard
            case .models: ModelsPane()
            case .history: ClipboardHistoryView()
            case .settings: GeneralSettingsPane()
            case .about: AboutPane()
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
        // One signal color across every control — system blue reads as unbranded default.
        .tint(Theme.violetAccent)
        .background(WindowConfigurator())
        .sheet(isPresented: $showOnboarding) { OnboardingView(isPresented: $showOnboarding) }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
    }

    /// Engine + shortcut at a glance, so the two things that break dictation are always
    /// visible without opening Settings.
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            RowDivider()
            HStack(spacing: 8) {
                Circle()
                    .fill(permissions.allGranted ? Theme.violetAccent : Theme.alert)
                    .frame(width: 6, height: 6)
                Text(permissions.allGranted ? "Ready" : "Permissions needed")
                    .font(Theme.rowMeta)
                    .foregroundStyle(permissions.allGranted ? .secondary : Theme.alert)
                Spacer()
            }
            KeyChip(text: HotkeyManager.currentPreset.label)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 8)
                dictateControl
                statusBlock
                if !permissions.allGranted { permissionNotice }
                statsRow
                if !dictation.lastTranscript.isEmpty { lastTranscriptCard }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    /// The one thing you remember: a live instrument. Concentric rings breathe with the
    /// actual mic level while recording, so the app visibly hears you before any text lands.
    private var dictateControl: some View {
        Button(action: { dictation.toggleDictation() }) {
            ZStack {
                let recording = dictation.state == .recording
                let amp = min(1, CGFloat(dictation.audioLevel) * 2.6)
                ForEach(0..<3, id: \.self) { ring in
                    let base: CGFloat = 132 + CGFloat(ring) * 26
                    Circle()
                        .stroke(
                            (recording ? Theme.alert : Theme.violetAccent)
                                .opacity(recording ? 0.30 - Double(ring) * 0.08 : 0.10 - Double(ring) * 0.03),
                            lineWidth: 1.5
                        )
                        .frame(width: base, height: base)
                        .scaleEffect(recording ? 1 + amp * (0.10 + CGFloat(ring) * 0.05) : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: dictation.audioLevel)
                }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: recording
                                ? [Theme.alert.opacity(0.95), Theme.alert.opacity(0.70)]
                                : [Theme.violetAccent, Theme.violetAccent.opacity(0.72)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 116, height: 116)
                    .shadow(color: (recording ? Theme.alert : Theme.violetAccent).opacity(0.35), radius: 22, y: 10)
                Image(systemName: recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 190)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: .option)
        .animation(Theme.motion, value: dictation.state)
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(headline).font(Theme.display).contentTransition(.numericText())
            HStack(spacing: 8) {
                Text(subhead).font(.callout).foregroundStyle(.secondary)
                KeyChip(text: HotkeyManager.currentPreset.label)
            }
        }
    }

    private var headline: String {
        switch dictation.state {
        case .idle: return "Ready to dictate"
        case .recording: return "Listening"
        case .transcribing: return "Transcribing"
        case .injecting: return "Inserted"
        }
    }

    private var subhead: String {
        dictation.state == .recording ? "Press again to finish" : "Works in any app —"
    }

    private var permissionNotice: some View {
        Card(padding: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.alert)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions needed").font(Theme.rowTitle)
                    Text("Microphone and Accessibility must be granted for dictation to type at your cursor.")
                        .font(Theme.rowMeta).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Open Settings") { sectionRaw = AppSection.settings.rawValue }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// Real numbers from the history store — no placeholder metrics.
    private var statsRow: some View {
        Card(padding: 18) {
            HStack(spacing: 0) {
                StatTile(figure: "\(history.items.count)", caption: "Dictations")
                RowDivider().frame(width: 1, height: 34)
                StatTile(figure: "\(todayCount)", caption: "Today")
                RowDivider().frame(width: 1, height: 34)
                StatTile(figure: "\(wordCount)", caption: "Words")
                RowDivider().frame(width: 1, height: 34)
                StatTile(figure: minutesLabel, caption: "Minutes")
            }
        }
    }

    private var todayCount: Int {
        history.items.filter { Calendar.current.isDateInToday($0.date) }.count
    }
    private var wordCount: Int {
        history.items.reduce(0) { $0 + $1.text.split(whereSeparator: { $0 == " " || $0.isNewline }).count }
    }
    /// Total speaking time. Items saved before durations were recorded are estimated at a
    /// typical 150 words-per-minute dictation pace.
    private var minutesLabel: String {
        let seconds = history.items.reduce(0.0) { total, item in
            let words = Double(item.text.split(whereSeparator: { $0 == " " || $0.isNewline }).count)
            return total + (item.duration ?? words / 150.0 * 60.0)
        }
        let minutes = seconds / 60.0
        return minutes < 10 ? String(format: "%.1f", minutes) : "\(Int(minutes))"
    }

    private var lastTranscriptCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel("Last transcript", systemImage: "text.bubble")
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(dictation.lastTranscript, forType: .string)
                    }.buttonStyle(.bordered)
                    Button("Paste Again") { TextInjector.inject(text: dictation.lastTranscript) }
                        .buttonStyle(.borderedProminent)
                }
                Text(dictation.lastTranscript)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.wellFill, in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
            }
        }
    }
}

/// Grabs the hosting NSWindow and marks it able to join fullscreen Spaces — without
/// `.fullScreenAuxiliary` + `.moveToActiveSpace`, clicking the Dock icon while another
/// app (e.g. Terminal) is fullscreen appears to do nothing.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            v.window?.collectionBehavior.insert([.fullScreenAuxiliary, .moveToActiveSpace])
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var stateSink: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring forward any history/settings orphaned under pre-`com.wispervoice.dev` ids.
        LegacyDefaults.migrateOnce()
        NSApp.setActivationPolicy(.regular) // Show in Dock so user can open
        NSApp.activate(ignoringOtherApps: false)
        // Ensure overlay singleton is created early
        _ = OverlayWindow.sharedInstance
        // Start tracking the frontmost app from launch so the first dictation has a paste target
        _ = FocusTracker.shared
        // The status item is the ONLY menu bar presence — SwiftUI MenuBarExtra is not used
        // (it silently fails to attach on this machine; the app ends up with no window in the
        // menu bar row at all). The explicit NSStatusItem is what has always shown reliably.
        ensureStatusItem()
        // Keep the icon in sync with dictation state (was MenuBarExtra's label before).
        stateSink = DictationManager.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateStatusIcon(for: state) }
        // Re-ensure after wake / display changes / app activation (menu bar gets rebuilt
        // on those), plus one delayed retry — on this machine's crowded menu bar the item
        // can be dropped at launch, and Dock-click activation is the natural repair path.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(ensureStatusItem), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(ensureStatusItem), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ensureStatusItem), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ensureStatusItem), name: NSApplication.didBecomeActiveNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.ensureStatusItem() }
        // Companion to present(_:): the main window is floated to appear over fullscreen
        // Spaces; return it to normal level as soon as the user switches away.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { note in
            if let w = note.object as? NSWindow, w.identifier?.rawValue == "main" {
                w.level = .normal
            }
        }
        FocusLog.log("launch: axTrusted=\(AXIsProcessTrusted()) build=\(Bundle.main.bundleIdentifier ?? "?")")
        PermissionsManager.checkAll()
        PermissionsManager.requestMicrophonePermissionAtLaunch()
        // Auto-register for startup if user enabled before
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            try? SMAppService.mainApp.register()
        }
        // First run: the onboarding sheet lives on the main window's ContentView, but the app
        // is menu-bar-first and nothing opens that window at launch — so a fresh install never
        // saw the walkthrough. Open it once until onboarding has been completed or skipped.
        if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.openMain() }
        }
    }

    @objc func openMain() {
        popover?.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Try main window first — force to active Space (incl. fullscreen Spaces) and above Chrome
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            present(window)
            // Also bring pill to front if recording
            if OverlayWindow.sharedInstance.isVisible { OverlayWindow.sharedInstance.orderFrontRegardless() }
            return
        }
        // Window not created yet — ask SwiftUI to open it, then pin it to the active Space
        NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
            if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                self.present(w)
            }
        }
    }

    /// Order the main window in over WHATEVER Space is active — including another app's
    /// fullscreen Space. `.fullScreenAuxiliary` alone was not enough for a titled window:
    /// at `.normal` level it stayed behind the fullscreen app's window, which read as the
    /// Dock icon "just not opening". Raising to `.floating` while key makes it appear;
    /// the resign-key observer (launch) drops it back so it never floats over other work.
    private func present(_ window: NSWindow) {
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
    /// Settings is a section of the main window — deep-link it, then open the window.
    @objc func openSettings() {
        UserDefaults.standard.set(ContentView.AppSection.settings.rawValue, forKey: "main.section")
        openMain()
    }

    @objc func ensureStatusItem() {
        if let item = statusItem, item.button != nil { return }
        // This Mac's menu bar is crowded enough that new status items overflow leftward
        // into the notch and the window server hides them (diagnosed: our item sat at
        // x=618, occluded=true — dead center under the notch). macOS places items by a
        // saved "preferred position" (distance from the right screen edge) keyed on
        // autosaveName; pre-seeding a small value pins us near the clock, never under
        // the notch. Only seeded when absent so a user's manual drag still sticks.
        let posKey = "NSStatusItem Preferred Position WisperVoice"
        if UserDefaults.standard.object(forKey: posKey) == nil {
            UserDefaults.standard.set(60, forKey: posKey)
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "WisperVoice"
        item.button?.toolTip = "WisperVoice — ⌥Space to dictate"
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self
        statusItem = item
        updateStatusIcon(for: DictationManager.shared.state)
        // Diagnose the "icon not visible" report: log where the window server actually put
        // the item. On a notched Mac, a crowded menu bar silently drops items — frame.origin
        // ends up at x=0 or the window is nil/offscreen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let win = self?.statusItem?.button?.window
            FocusLog.log("statusItem: window=\(win.map { "\($0.frame)" } ?? "nil") visible=\(win?.isVisible ?? false) occluded=\(win.map { !$0.occlusionState.contains(.visible) } ?? true)")
        }
    }

    private func updateStatusIcon(for state: DictationState) {
        let name: String
        switch state {
        case .idle: name = "waveform"
        case .recording: name = "waveform.badge.mic"
        case .transcribing: name = "waveform.badge.ellipsis"
        case .injecting: name = "checkmark.circle"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "WisperVoice")
        img?.isTemplate = true
        statusItem?.button?.image = img
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover == nil {
            let host = NSHostingController(rootView: MenuBarView()
                .environmentObject(DictationManager.shared)
                .environmentObject(PermissionsManager.shared)
                .environmentObject(ModelManager.shared))
            host.sizingOptions = .preferredContentSize
            let p = NSPopover()
            p.contentViewController = host
            p.behavior = .transient // click anywhere else to dismiss
            popover = p
        }
        if let p = popover, p.isShown {
            p.performClose(sender)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
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
