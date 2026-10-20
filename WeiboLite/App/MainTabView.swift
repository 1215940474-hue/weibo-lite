import SwiftUI

extension Notification.Name {
    /// 刷新首页（工具栏刷新按钮 / 重复点击首页时使用）
    static let homeRefreshRequested = Notification.Name("weibolite.homeRefresh")
}

/// 还原 v0.1 的原生外观：系统 TabView（原生液态玻璃 + 选中滑动动画）
struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home
        case hot
        case search
        case me
    }

    var body: some View {
        TabView(selection: $selection) {
            FeedView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(Tab.home)

            HotTabView()
                .tabItem {
                    Label("热搜", systemImage: "flame.fill")
                }
                .tag(Tab.hot)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            MeView()
                .tabItem {
                    Label("我", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.me)
        }
    }
}
