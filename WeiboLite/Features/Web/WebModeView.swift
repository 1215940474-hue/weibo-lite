import SwiftUI
import WebKit

/// 兜底方案：直接打开 m.weibo.cn 网页，并注入脚本隐藏带「推广 / 广告」字样的卡片。
/// 原生接口失效时，至少还能刷网页版。
struct WebModeView: View {
    @State private var isLoading = true

    var body: some View {
        ZStack {
            WeiboWebView(isLoading: $isLoading)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView()
                    .padding(20)
                    .glassCapsule()
            }
        }
        .navigationTitle("网页模式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeiboWebView: UIViewRepresentable {
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: AdBlockScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = WeiboBrowser.userAgent

        if let url = URL(string: "https://m.weibo.cn/") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}

/// 网页版去广告：只隐藏「短文案 + 含推广关键词」的卡片，避免误伤正文。
private enum AdBlockScript {
    static let source = """
    (function() {
        var keywords = ['推广', '广告', '赞助'];
        function clean() {
            var nodes = document.querySelectorAll('.card, article, .m-panel, .card9');
            for (var i = 0; i < nodes.length; i++) {
                var node = nodes[i];
                if (node.dataset.weiboliteHidden) { continue; }
                var text = (node.innerText || '').trim();
                if (!text || text.length > 80) { continue; }
                for (var k = 0; k < keywords.length; k++) {
                    if (text.indexOf(keywords[k]) >= 0) {
                        node.style.display = 'none';
                        node.dataset.weiboliteHidden = '1';
                        break;
                    }
                }
            }
        }
        clean();
        setInterval(clean, 1500);
    })();
    """
}
