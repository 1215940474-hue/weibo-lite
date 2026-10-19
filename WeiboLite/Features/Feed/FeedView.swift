import Combine
import SwiftUI

/// 热搜点击后要跳转的搜索页
struct SearchRoute: Hashable {
    let keyword: String
}

struct FeedView: View {
    enum HomeTab: String, CaseIterable {
        case recommend = "推荐"
        case following = "关注"
        case hot = "热搜"
    }

    @StateObject private var recommendStore = FeedStore(source: .recommend)
    @StateObject private var followingStore = FeedStore(source: .following)
    @State private var tab: HomeTab = .recommend

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("分组", selection: $tab) {
                    ForEach(HomeTab.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 4)
                .padding(.bottom, 6)

                switch tab {
                case .recommend:
                    FeedList(store: recommendStore)
                case .following:
                    FeedList(store: followingStore)
                case .hot:
                    HotSearchView()
                }
            }
            .background(AppBackground())
            .navigationTitle("微博轻读")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { mid in
                StatusDetailView(mid: mid)
            }
            .navigationDestination(for: SearchRoute.self) { route in
                SearchResultView(keyword: route.keyword)
            }
        }
    }
}

/// 信息流列表（推荐 / 关注 / 搜索结果 / 用户主页共用）。
struct FeedList: View {
    @ObservedObject var store: FeedStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let message = store.errorMessage, store.items.isEmpty {
                    ErrorStateView(message: message) {
                        Task { await store.reload() }
                    }
                }

                ForEach(store.items) { status in
                    StatusCardView(status: status)
                        .onAppear {
                            if status.navKey == store.items.last?.navKey {
                                Task { await store.loadMore() }
                            }
                        }
                }

                if store.isLoadingMore {
                    ProgressView().padding(.vertical, 12)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.reload() }
        .overlay {
            if store.isLoading, store.items.isEmpty {
                ProgressView()
            }
        }
        .overlay(alignment: .top) {
            TopBlurFade()
        }
        .task {
            if store.items.isEmpty { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weiboDidLogin)) { _ in
            Task { await store.reload() }
        }
    }
}
