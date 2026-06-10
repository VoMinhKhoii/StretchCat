import SwiftUI

/// The lively dropdown shown from the menu bar icon (window-style MenuBarExtra).
struct MenuPanel: View {
    @ObservedObject var manager: ReminderManager
    /// Closes the popover (provided by the MenuBarExtra environment).
    var dismiss: () -> Void

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let cream = Color(red: 0.980, green: 0.976, blue: 0.969)
    private let accent = Color.orange

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onReceive(tick) { now = $0 }
    }

    // MARK: Header — live cat + countdown

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LoopingVideo(resource: "cat_stretch")
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .background(cream)

            // Legibility gradient under the text.
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.55)],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: 132)
            .allowsHitTesting(false)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Stretch Cat")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(statusLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Spacer()
                Image(systemName: manager.isPaused ? "pause.circle.fill" : "figure.flexibility")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 11)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            Button(action: { dismiss(); manager.stretchNow() }) {
                Label("Stretch now", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)

            // Interval segmented picker
            VStack(alignment: .leading, spacing: 6) {
                Text("REMIND ME EVERY")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(.tertiary)
                Picker("", selection: Binding(
                    get: { manager.intervalHours },
                    set: { manager.intervalHours = $0 }
                )) {
                    Text("1 hour").tag(1)
                    Text("2 hours").tag(2)
                    Text("3 hours").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            Toggle(isOn: Binding(
                get: { !manager.isPaused },
                set: { manager.isPaused = !$0 }
            )) {
                Label("Reminders", systemImage: "bell.fill")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .tint(accent)

            Toggle(isOn: $manager.launchAtLogin) {
                Label("Launch at login", systemImage: "power")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .tint(accent)

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit Stretch Cat", systemImage: "xmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: Status

    private var statusLine: String {
        guard !manager.isPaused else { return "Reminders paused" }
        guard let date = manager.nextFireDate else { return "Scheduling…" }
        let remaining = max(0, date.timeIntervalSince(now))
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        if h > 0 { return "Next stretch in \(h)h \(m)m" }
        if m > 0 { return "Next stretch in \(m)m" }
        return "Next stretch in under a minute"
    }
}
