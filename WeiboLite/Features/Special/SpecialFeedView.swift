import Combine
import SwiftUI

extension Notification.Name {
    /// 特别关注流刷新请求
    static let specialFeedRefreshRequested = Notification.Name("weibolite.specialFeedRefresh")
}

/// 「特别关注」分组：把名单里每个人的微博按时间合并
struct SpecialFeedView: View {
    @StateObject private var store = SpecialFeedStore()
    @ObservedObject private var specials = SpecialFollowStore.shared

    var body: some View {
        Group {
            if specials.users.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .onAppear {
            Task { await store.reload() }
        }
        .onChange(of: specials.users) { _, _ in
            Task { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .specialFeedRefreshRequested)) { _ in
            Task { await store.reload() }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                header

                if let message = store.errorMessage, store.items.isEmpty {
                    ErrorStateView(message: message) {
                        Task { await store.reload() }
                    }
                }

                ForEach(store.items) { status in
                    StatusCardView(status: status)
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
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text("特别关注 · \(specials.users.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text("按时间合并")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "star")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("还没有特别关注的人")
                    .font(.headline)
                Text("进入任意博主的主页，点右上角 ★ 加入特别关注，\n他们的微博会按时间合并出现在这里。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
            .padding(.horizontal, 32)
        }
        .refreshable { await store.reload() }
    }
}
