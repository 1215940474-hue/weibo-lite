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
        VStack(spacing: 0) {
            topBar

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
                            .onAppear {
                                if status.navKey == store.items.last?.navKey, store.canLoadMore {
                                    Task { await store.loadMore() }
                                }
                            }
                    }

                    if store.isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await loadProfile()
                await store.reload()
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadProfile()
            if store.items.isEmpty {
                await store.reload()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(user?.screenName ?? "个人主页")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemBackground))
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
