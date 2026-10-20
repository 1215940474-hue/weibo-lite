import Combine
import SwiftUI

/// 热搜独立页（底部导航栏单列）
struct HotTabView: View {
    var body: some View {
        NavigationStack {
            HotSearchView()
                .safeAreaInset(edge: .top, spacing: 0) {
                    GlassPageHeader(title: "热搜")
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: SearchRoute.self) { route in
                    SearchResultView(keyword: route.keyword)
                }
                .navigationDestination(for: String.self) { mid in
                    StatusDetailView(mid: mid)
                }
                .navigationDestination(for: UserRoute.self) { route in
                    UserProfileView(uid: route.uid)
                }
        }
    }
}
