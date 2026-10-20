import SwiftUI

/// 只保留登录/视频两个系统呈现（图片查看器改成自绘覆盖层，才能做出缩放淡入的动效）
private enum ActiveCover: Identifiable {
    case login
    case video(URL)

    var id: String {
        switch self {
        case .login:
            return "login"
        case .video(let url):
            return url.absoluteString
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: WeiboSession
    @AppStorage("weibolite.didSkipLogin") private var didSkipLogin = false
    @StateObject private var media = MediaPresenter()
    @State private var cover: ActiveCover?

    var body: some View {
        ZStack {
            MainTabView()
                .environment(\.mediaPresenter, media)
                .task {
                    CrashTrace.log("root task, loggedIn=\(session.isLoggedIn)")
                    if session.isLoggedIn {
                        await session.refreshProfile()
                    }
                    guard !session.isLoggedIn, !didSkipLogin else { return }
                    cover = .login
                }
                .onChange(of: session.isLoggedIn) { _, newValue in
                    if newValue {
                        NotificationCenter.default.post(name: .weiboDidLogin, object: nil)
                    }
                }
                .onChange(of: media.videoURL?.id) { _, _ in
                    guard let item = media.videoURL else { return }
                    media.videoURL = nil
                    cover = .video(item.url)
                }
                .fullScreenCover(item: $cover) { item in
                    switch item {
                    case .login:
                        LoginView()
                    case .video(let url):
                        FullScreenVideoPlayer(url: url)
                    }
                }

            // 图片查看器：自绘覆盖层 + 缩放淡入，而不是系统的上下滑入
            if let payload = media.imagePayload {
                ImageViewer(payload: payload, onClose: { media.closeImage(ifMatches: payload.id) })
                    .id(payload.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(20)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: media.imagePayload?.id)
    }
}
