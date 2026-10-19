import AVFoundation
import AVKit
import SwiftUI

/// 同一时刻只允许一个视频播放，降低多 AVPlayer 并发解码导致的崩溃概率
@MainActor
private enum VideoRegistry {
    static weak var current: AVPlayer?

    static func activate(_ player: AVPlayer) {
        if let current = current, current !== player {
            current.pause()
        }
        current = player
    }

    static func release(_ player: AVPlayer) {
        player.pause()
        if current === player {
            current = nil
        }
    }
}

/// 微博视频播放：
/// - 自动播放（默认静音，可点喇叭开声音）
/// - .ambient 音频会话，不占用灵动岛/锁屏的「正在播放」控件
/// - 竖屏/长视频预览更高，横屏 16:9
/// - 点击全屏按钮/双击画面 → 根视图统一呈现全屏播放器
struct WeiboVideoPlayer: View {
    let url: URL

    @Environment(\.mediaPresenter) private var media: MediaPresenter
    @State private var player: AVPlayer?
    @State private var aspect: CGFloat = 16.0 / 9.0
    @State private var isMuted = true

    private var isPortrait: Bool { aspect < 1 }

    private var previewHeight: CGFloat {
        let width = UIScreen.main.bounds.width - Theme.pagePadding * 2 - 28
        if isPortrait {
            return min(width * 1.45, 520)
        }
        return width * 9.0 / 16.0
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: previewHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .contentShape(Rectangle())
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: previewHeight)
                        .overlay { ProgressView() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                Button {
                    toggleMute()
                } label: {
                    icon(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }

                Button {
                    player?.pause()
                    media.openVideo(url)
                } label: {
                    icon("arrow.up.left.and.arrow.down.right")
                }
            }
            .padding(8)
        }
        .onAppear { setupIfNeeded() }
        .onDisappear {
            if let player = player {
                VideoRegistry.release(player)
            }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(7)
            .background(Color.black.opacity(0.45), in: Circle())
    }

    private func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        player.isMuted = isMuted
    }

    private func setupIfNeeded() {
        guard player == nil else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.allowsExternalPlayback = false
        player = newPlayer
        VideoRegistry.activate(newPlayer)
        CrashTrace.log("video setup \(url.absoluteString.prefix(100))")
        newPlayer.play()

        Task {
            if let track = try? await item.asset.loadTracks(withMediaType: .video).first,
               let size = try? await track.load(.naturalSize),
               size.width > 0, size.height > 0 {
                let width = abs(size.width)
                let height = abs(size.height)
                aspect = height > width ? width / height : 16.0 / 9.0
            }
        }
    }
}

/// 全屏播放器（由根视图通过 MediaPresenter 呈现，自己的 player，避免和列表里的抢资源）
struct FullScreenVideoPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .padding()
        }
        .onAppear {
            guard player == nil else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .moviePlayback, options: [.mixWithOthers])
            let newPlayer = AVPlayer(url: url)
            newPlayer.allowsExternalPlayback = false
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
