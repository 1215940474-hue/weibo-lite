import Combine
import SwiftUI

/// 热搜独立页（底部导航栏单列）
struct HotTabView: View {
    var body: some View {
        NavigationStack {
            HotSearchView()
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
