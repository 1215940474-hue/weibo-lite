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
        case special = "特别关注"
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
                .padding(.top, 6)
                .padding(.bottom, 6)

                switch tab {
                case .recommend:
                    FeedList(store: recommendStore)
                case .following:
                    FeedList(store: followingStore)
                case .special:
                    SpecialFeedView()
                }
            }
            .background(AppBackground())
            .navigationTitle("微博轻读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshCurrentTab()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(for: String.self) { mid in
                StatusDetailView(mid: mid)
            }
            .navigationDestination(for: UserRoute.self) { route in
                UserProfileView(uid: route.uid)
            }
            .navigationDestination(for: SearchRoute.self) { route in
                SearchResultView(keyword: route.keyword)
            }
            .onReceive(NotificationCenter.default.publisher(for: .homeRefreshRequested)) { _ in
                refreshCurrentTab()
            }
        }
    }

    private func refreshCurrentTab() {
        switch tab {
        case .recommend:
            Task { await recommendStore.reload() }
        case .following:
            Task { await followingStore.reload() }
        case .special:
            NotificationCenter.default.post(name: .specialFeedRefreshRequested, object: nil)
        }
    }
}

/// 信息流列表（推荐 / 关注 / 搜索结果 / 用户主页共用）
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
                        .equatable()
                }

                if store.isLoadingMore {
                    ProgressView().padding(.vertical, 12)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.reload() }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let scrollable = geometry.contentSize.height > geometry.containerSize.height + 40
            let nearBottom = geometry.contentOffset.y + geometry.containerSize.height
                > geometry.contentSize.height - 600
            return scrollable && nearBottom
        } action: { _, isNearBottom in
            guard isNearBottom else { return }
            Task { await store.loadMore() }
        }
        .overlay {
            if store.isLoading, store.items.isEmpty {
                ProgressView()
            }
        }
        .task {
            if store.items.isEmpty { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weiboDidLogin)) { _ in
            Task { await store.reload() }
        }
    }
}
