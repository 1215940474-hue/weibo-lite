import Combine
import SwiftUI

/// 我的关注列表：支持搜索、点进博主主页、上拉加载
struct MyFollowingView: View {
    @EnvironmentObject private var session: WeiboSession
    @StateObject private var store = FollowingListStore()
    @State private var keyword = ""

    private var filteredUsers: [WBUser] {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.users }
        return store.users.filter {
            $0.screenName.localizedCaseInsensitiveContains(query)
                || $0.descriptionText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.isLoading, store.users.isEmpty {
                        ProgressView().padding(.top, 40)
                    }

                    if let message = store.errorMessage, store.users.isEmpty {
                        ErrorStateView(message: message) {
                            Task { await store.load(uid: session.uid) }
                        }
                    }

                    ForEach(filteredUsers) { user in
                        NavigationLink(value: UserRoute(uid: user.uid)) {
                            userRow(user)
                        }
                        .buttonStyle(.plain)
                    }

                    if store.isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }

                    if !store.users.isEmpty {
                        Text("共 \(store.users.count) 人")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.load(uid: session.uid) }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let scrollable = geometry.contentSize.height > geometry.containerSize.height + 40
                let nearBottom = geometry.contentOffset.y + geometry.containerSize.height
                    > geometry.contentSize.height - 400
                return scrollable && nearBottom
            } action: { _, isNearBottom in
                guard isNearBottom else { return }
                Task { await store.loadMore() }
            }
        }
        .background(AppBackground())
        .navigationTitle("我的关注")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.users.isEmpty { await store.load(uid: session.uid) }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索关注的人", text: $keyword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassCapsule()
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 8)
    }

    private func userRow(_ user: WBUser) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: user.avatarURL, size: 40, fallbackText: String(user.screenName.prefix(1)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.screenName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    if user.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if !user.descriptionText.isEmpty {
                    Text(user.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
