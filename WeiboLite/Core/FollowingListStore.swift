import Combine
import Foundation

/// 我的「关注列表」：从个人主页页签解析 containerid，再按卡片里的 user 拉取。
@MainActor
final class FollowingListStore: ObservableObject {
    @Published private(set) var users: [WBUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = true

    private var containerID: String?
    private var page = 1
    private var seen: Set<String> = []
    private var emptyLoadCount = 0

    func load(uid: String) async {
        if ScreenshotMode.isEnabled {
            users = ScreenshotFixtures.followingUsers
            errorMessage = nil
            canLoadMore = false
            return
        }
        guard !uid.isEmpty else {
            errorMessage = "还没登录，先登录微博。"
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        page = 1
        seen = []
        emptyLoadCount = 0
        canLoadMore = true
        defer { isLoading = false }

        if containerID == nil {
            containerID = await FeedTabsResolver.shared.profileTab(
                uid: uid,
                containing: "关注",
                excluding: ["粉丝", "特别关注"]
            )
        }

        guard let container = containerID else {
            errorMessage = "读不到关注列表（微博接口可能已调整）。"
            return
        }

        if let list = try? await fetch(container: container, page: 1), !list.isEmpty {
            seen = Set(list.map { $0.uid })
            users = list
        } else {
            errorMessage = "关注列表是空的，或接口暂时不可用。"
        }
    }

    func loadMore() async {
        guard let container = containerID, !isLoading, !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let next = page + 1
        guard let list = try? await fetch(container: container, page: next) else { return }
        page = next

        var added: [WBUser] = []
        for user in list where !user.uid.isEmpty && !seen.contains(user.uid) {
            seen.insert(user.uid)
            added.append(user)
        }
        if added.isEmpty {
            emptyLoadCount += 1
            if emptyLoadCount >= 2 { canLoadMore = false }
        } else {
            emptyLoadCount = 0
            users.append(contentsOf: added)
        }
    }

    private func fetch(container: String, page: Int) async throws -> [WBUser] {
        guard let url = WeiboEndpoint.container(id: container, page: page) else {
            throw WeiboAPIError.badURL
        }
        let response: ContainerResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        // 关注列表的卡片：card_type=11，每个卡片带 user 字段
        return data.cards.compactMap { $0.user }
    }
}
