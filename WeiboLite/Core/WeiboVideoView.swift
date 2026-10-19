import AVFoundation
import AVKit
import SwiftUI

/// 微博视频播放：
/// - 自动播放（默认静音，可点喇叭开声音）
/// - 使用 .ambient 音频会话，不占用灵动岛/锁屏的「正在播放」控件
/// - 竖屏/长视频预览更高，横屏保持 16:9
/// - 点击画面或全屏按钮进入全屏
/// - 优先加载最高画质
struct WeiboVideoPlayer: View {
    let url: URL
    /// 微博接口给的封面比例（可选），拿不到就等 AVAsset 探测
    var fallbackAspect: CGFloat = 16.0 / 9.0

    @State private var player: AVPlayer?
    @State private var aspect: CGFloat = 16.0 / 9.0
    @State private var isMuted = true
    @State private var showFullScreen = false

    private var isPortrait: Bool { aspect < 1 }

    /// 预览高度：横屏 16:9；竖屏/长视频更高
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
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded { showFullScreen = true }
                        )
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
                    showFullScreen = true
                } label: {
                    icon("arrow.up.left.and.arrow.down.right")
                }
            }
            .padding(8)
        }
        .onAppear { setupIfNeeded() }
        .onDisappear { player?.pause() }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenVideoView(player: player, onClose: { showFullScreen = false })
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

        // .ambient：不进入「正在播放」，不会出现在灵动岛/锁屏
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.allowsExternalPlayback = false
        player = newPlayer
        newPlayer.play()

        Task {
            if let track = try? await item.asset.loadTracks(withMediaType: .video).first,
               let size = try? await track.load(.naturalSize),
               size.width > 0, size.height > 0 {
                let width = abs(size.width)
                let height = abs(size.height)
                if height > width {
                    aspect = width / height
                } else {
                    aspect = 16.0 / 9.0
                }
            }
        }
    }
}

/// 全屏播放
private struct FullScreenVideoView: View {
    let player: AVPlayer?
    let onClose: () -> Void

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
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .padding()
        }
    }
}
