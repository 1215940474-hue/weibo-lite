import SwiftUI

/// 同一个视图上只挂一个 fullScreenCover，避免多个呈现器互相抢占导致崩溃。
private enum ActiveCover: Identifiable {
    case login
    case image(ImageViewerPayload)
    case video(URL)

    var id: String {
        switch self {
        case .login:
            return "login"
        case .image(let payload):
            return payload.id.uuidString
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
            .onChange(of: media.imagePayload?.id) { _, _ in
                guard let payload = media.imagePayload else { return }
                media.imagePayload = nil
                cover = .image(payload)
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
                case .image(let payload):
                    ImageViewer(payload: payload)
                case .video(let url):
                    FullScreenVideoPlayer(url: url)
                }
            }
    }
}
