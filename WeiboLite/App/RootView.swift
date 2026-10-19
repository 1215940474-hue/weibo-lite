import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: WeiboSession
    @AppStorage("weibolite.didSkipLogin") private var didSkipLogin = false
    @State private var showLogin = false

    var body: some View {
        MainTabView()
            .task {
                guard !session.isLoggedIn, !didSkipLogin else { return }
                showLogin = true
            }
            .onChange(of: session.isLoggedIn) { _, newValue in
                if newValue {
                    NotificationCenter.default.post(name: .weiboDidLogin, object: nil)
                }
            }
            .fullScreenCover(isPresented: $showLogin) {
                LoginView()
            }
    }
}
