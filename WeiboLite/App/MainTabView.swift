import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("首页", systemImage: "house.fill") }

            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }

            MeView()
                .tabItem { Label("我", systemImage: "person.crop.circle") }
        }
    }
}
