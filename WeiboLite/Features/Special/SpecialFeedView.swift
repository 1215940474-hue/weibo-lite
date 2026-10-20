import Combine
import SwiftUI

extension Notification.Name {
    /// 特别关注流刷新请求
    static let specialFeedRefreshRequested = Notification.Name("weibolite.specialFeedRefresh")
}

/// 「特别关注」分组：读取微博账号自己的特别关注分组
struct SpecialFeedView: View {
    @StateObject private var store = SpecialFeedStore()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                header

                if store.isLoading, store.items.isEmpty {
                    ProgressView().padding(.top, 40)
                }

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
            .padding(.top, 6)
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
        .task {
            if store.items.isEmpty { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .specialFeedRefreshRequested)) { _ in
            Task { await store.reload() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text("微博「特别关注」")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}
