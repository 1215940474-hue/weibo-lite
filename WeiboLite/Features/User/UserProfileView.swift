import SwiftUI

struct UserRoute: Hashable {
    let uid: String
}

/// 个人主页：资料卡 + TA 的微博列表
struct UserProfileView: View {
    let uid: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: FeedStore
    @State private var user: WBUser?
    @State private var isLoadingProfile = true

    init(uid: String) {
        self.uid = uid
        _store = StateObject(wrappedValue: FeedStore(source: .user(uid: uid)))
    }

    var body: some View {
        ScrollView {
                LazyVStack(spacing: 10) {
                    profileCard

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
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await loadProfile()
                await store.reload()
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let scrollable = geometry.contentSize.height > geometry.containerSize.height + 40
                let nearBottom = geometry.contentOffset.y + geometry.containerSize.height
                    > geometry.contentSize.height - 600
                return scrollable && nearBottom
            } action: { _, isNearBottom in
                guard isNearBottom else { return }
                Task { await store.loadMore() }
            }
        .background(AppBackground())
        .navigationTitle(user?.screenName ?? "个人主页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleSpecial()
                } label: {
                    Image(systemName: isSpecial ? "star.fill" : "star")
                        .foregroundStyle(isSpecial ? Color.yellow : Color.secondary)
                }
            }
        }
        .task {
            await loadProfile()
            if store.items.isEmpty {
                await store.reload()
            }
        }
    }

    private var isSpecial: Bool {
        guard let uid = user?.uid, !uid.isEmpty else { return false }
        return SpecialFollowStore.shared.isSpecial(uid)
    }

    private func toggleSpecial() {
        guard let user = user, !user.uid.isEmpty else { return }
        SpecialFollowStore.shared.toggle(
            uid: user.uid,
            name: user.screenName,
            avatar: user.avatarURL
        )
    }

    private var profileCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    AvatarView(url: user?.avatarURL, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(user?.screenName ?? (isLoadingProfile ? "加载中…" : "微博用户"))
                                .font(.headline)
                            if user?.verified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        if let desc = user?.descriptionText, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Text("UID \(uid)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("TA 的微博")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func loadProfile() async {
        guard isLoadingProfile else { return }
        defer { isLoadingProfile = false }
        guard let url = WeiboEndpoint.userProfileContainer(uid: uid) else { return }
        if let response: ContainerResponse = try? await WeiboAPI.shared.get(url) {
            user = response.data?.userInfo
        }
    }
}
