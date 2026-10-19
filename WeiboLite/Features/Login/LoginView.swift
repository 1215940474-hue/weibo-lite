import SwiftUI
import WebKit

/// 内置微博登录页。登录成功后从 WKWebView 里取 weibo.cn 域名的 Cookie。
struct LoginView: View {
    @EnvironmentObject private var session: WeiboSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weibolite.didSkipLogin") private var didSkipLogin = false
    @State private var detectedCookies = false

    var body: some View {
        NavigationStack {
            ZStack {
                WeiboLoginWebView { cookies in
                    guard !detectedCookies else { return }
                    detectedCookies = true
                    session.update(cookies: cookies)
                    Task {
                        await session.refreshProfile()
                        dismiss()
                    }
                }

                if !session.isLoggedIn {
                    VStack(spacing: 4) {
                        Text("在下方页面登录你的微博账号")
                            .font(.footnote)
                        Text("登录成功后会自动返回")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassCapsule()
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationTitle("登录微博")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("先逛逛") {
                        didSkipLogin = true
                        dismiss()
                    }
                }
            }
        }
    }
}

/// WKWebView 登录页：每次页面加载完成就检查一次 Cookie。
private struct WeiboLoginWebView: UIViewRepresentable {
    private let handleCookies: @MainActor ([HTTPCookie]) -> Void

    init(handleCookies: @MainActor @escaping ([HTTPCookie]) -> Void) {
        self.handleCookies = handleCookies
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = WeiboBrowser.userAgent

        let loginURL = "https://passport.weibo.com/sso/signin?entry=wapsso&source=wapssoweb&url=https%3A%2F%2Fm.weibo.cn%2F"
        if let url = URL(string: loginURL) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(handleCookies: handleCookies)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let handleCookies: @MainActor ([HTTPCookie]) -> Void

        init(handleCookies: @MainActor @escaping ([HTTPCookie]) -> Void) {
            self.handleCookies = handleCookies
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let handler = handleCookies
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let weiboCookies = cookies.filter { $0.domain.contains("weibo.cn") }
                guard weiboCookies.contains(where: { $0.name == "SUB" && !$0.value.isEmpty }) else {
                    return
                }
                Task { @MainActor in
                    handler(weiboCookies)
                }
            }
        }
    }
}

enum WeiboBrowser {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}
