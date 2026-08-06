import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var step = 0
    private let steps: [(icon: String, title: String, desc: String, color: Color)] = [
        ("waveform.and.mic", "Welcome to WisperVoice", "System-wide dictation — speak in any app, live pill, auto-paste at cursor.", .purple),
        ("checkmark.shield.fill", "1. Grant Permissions", "Microphone + Speech Recognition + Accessibility (to paste at cursor). Do it once.", .orange),
        ("keyboard.badge.ellipsis", "2. Press to Dictate", "⌥Space or Fn×2 to start/stop. 5s silence auto-sends (toggle in Settings).", .blue),
        ("captions.bubble.fill", "3. See Live Pill", "Live transcript + waveform + Copy + × close. Drag? No — centered bottom.", .green),
        ("clock.arrow.circlepath", "4. History & Clipboard", "Every transcript saved. Menu bar → History, or Clipboard window → Copy/Paste.", .indigo),
    ]

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $step) {
                ForEach(0..<steps.count, id: \.self) { i in
                    let s = steps[i]
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(s.color.opacity(0.12)).frame(width: 84, height: 84)
                            Image(systemName: s.icon).font(.system(size: 36, weight: .semibold)).foregroundStyle(s.color)
                        }
                        Text(s.title).font(.title3.weight(.semibold).monospacedDigit()).multilineTextAlignment(.center)
                        Text(s.desc).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 12)
                        if i == 1 {
                            PermissionsQuickRow()
                        }
                    }
                    .tag(i)
                    .padding(16)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 260)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))

            HStack {
                Button("Skip") {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    isPresented = false
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }.buttonStyle(.bordered).controlSize(.small)
                }
                Button(step == steps.count - 1 ? "Get Started" : "Next") {
                    if step == steps.count - 1 {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        isPresented = false
                    } else { withAnimation { step += 1 } }
                }
                .buttonStyle(.borderedProminent).controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle().fill(i == step ? Color.accentColor : Color.primary.opacity(0.2)).frame(width: 7, height: 7).animation(.easeInOut(duration: 0.2), value: step)
                }
            }
        }
        .padding(22)
        .frame(width: 520, height: 420)
        .background(.background)
    }
}

private struct PermissionsQuickRow: View {
    @StateObject var pm = PermissionsManager()
    var body: some View {
        VStack(spacing: 6) {
            ForEach([("Mic", pm.micGranted), ("Speech", pm.speechGranted), ("Accessibility", pm.accessibilityGranted)], id: \.0) { t in
                HStack(spacing: 6) {
                    Image(systemName: t.1 ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(t.1 ? .green : .orange).font(.caption)
                    Text(t.0).font(.caption.weight(.medium))
                    Spacer()
                    if t.1 { Text("Granted").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            Button("Recheck") { pm.refresh() }.font(.caption).buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(10).background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear { pm.refresh() }
    }
}
