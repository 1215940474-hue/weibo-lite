import AVKit
import SwiftUI

/// 微博视频播放（AVPlayer 原生控件）。
struct WeiboVideoPlayer: View {
    let url: URL
    var aspectRatio: CGFloat = 16.0 / 9.0

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                Color.black.overlay { ProgressView().tint(.white) }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            guard player == nil else { return }
            let newPlayer = AVPlayer(url: url)
            newPlayer.isMuted = false
            player = newPlayer
        }
        .onDisappear {
            player?.pause()
        }
    }
}
