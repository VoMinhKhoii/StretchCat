import SwiftUI
import AVFoundation
import AppKit

/// Plays a bundled video on a seamless loop, muted, scaled to fill.
struct LoopingVideo: NSViewRepresentable {
    let resource: String   // e.g. "cat_stretch"

    func makeNSView(context: Context) -> PlayerNSView {
        PlayerNSView(resource: resource)
    }

    func updateNSView(_ nsView: PlayerNSView, context: Context) {}

    final class PlayerNSView: NSView {
        private var looper: AVPlayerLooper?
        private let queuePlayer = AVQueuePlayer()
        private let playerLayer = AVPlayerLayer()

        init(resource: String) {
            super.init(frame: .zero)
            wantsLayer = true
            layer = CALayer()

            guard let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else { return }
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .advance

            playerLayer.player = queuePlayer
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = bounds
            layer?.addSublayer(playerLayer)
            queuePlayer.play()
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }

        deinit { queuePlayer.pause() }
    }
}
