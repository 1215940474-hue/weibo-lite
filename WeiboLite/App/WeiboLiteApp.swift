import SwiftUI

@main
struct WeiboLiteApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(WeiboSession.shared)
                .tint(.blue)
        }
    }
}
