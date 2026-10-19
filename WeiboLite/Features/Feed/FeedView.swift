import Combine
import SwiftUI

struct FeedView: View {
    enum FeedTab: String, CaseIterable {
        case following = "关注"
        case recommend = "推荐"
    }

    @StateObject private var followingStore = FeedStore(source: .following)
    @StateObject private var recommendStore = FeedStore(source: .recommend)
    @State private var tab: FeedTab = .recommend

    private var currentStore: FeedStore {
        tab == .recommend ? recommendStore : followingStore
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("信息流", selection: $tab) {
                    ForEach(FeedTab.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 8)

                FeedList(store: currentStore)
            }
            .background(AppBackground())
            .navigationTitle("微博轻读")
            .navigationDestination(for: String.self) { mid in
                StatusDetailView(mid: mid)
            }
        }
    }
}

/// 信息流列表（推荐 / 关注 / 搜索结果共用）。
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
                    NavigationLink(value: status.navKey) {
                        StatusCardView(status: status)
                    }
                    .buttonStyle(.plain)
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
        .task {
            if store.items.isEmpty { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weiboDidLogin)) { _ in
            Task { await store.reload() }
        }
    }
}
