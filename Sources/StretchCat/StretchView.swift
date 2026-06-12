import SwiftUI
import AppKit
import StretchCatCore

/// The follow-along card: the cat plays its full stretch routine on a loop,
/// with a cue, an auto-dismiss countdown, and Snooze / Done controls.
struct StretchView: View {
    let exercise: Exercise
    var onDone: () -> Void
    var onSnooze: () -> Void

    @State private var secondsLeft = StretchSchedule.autoCloseSeconds
    @State private var appear = false

    private let countdown = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Cream tone matched to the video background so the cat blends in.
    private let cream = Color(red: 0.980, green: 0.976, blue: 0.969)

    var body: some View {
        VStack(spacing: 0) {
            // Cat video — fills the top of the card.
            LoopingVideo(resource: "cat_stretch")
                .frame(width: 340, height: 232)
                .background(cream)

            VStack(spacing: 14) {
                Text("TIME TO STRETCH")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(2.0)
                    .foregroundStyle(Color.orange)

                VStack(spacing: 5) {
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(exercise.cue)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 290)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button(action: onSnooze) {
                        Text("Snooze 10m")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onDone) {
                        Text("Done ✓")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut(.defaultAction)
                }

                Text("Auto-closes in \(secondsLeft)s")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(width: 340)
            .background(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 26, y: 10)
        .scaleEffect(appear ? 1 : 0.92)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { appear = true }
        }
        .onReceive(countdown) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
            if secondsLeft == 0 { onDone() }
        }
    }
}
