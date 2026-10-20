import Combine
import Foundation

/// 「特别关注」流：读取微博账号自己的特别关注分组。
/// 优先从首页 tabsInfo 解析真实 containerid，失败后再逐个试常见候选。
@MainActor
final class SpecialFeedStore: ObservableObject {
    @Published private(set) var items: [MBlog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = true

    private var containerID: String?
    private var cursor: String = ""
    private var seen: Set<String> = []
    private var emptyLoadCount = 0

    func reload() async {
        if ScreenshotMode.isEnabled {
            items = ScreenshotFixtures.special
            errorMessage = nil
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        containerID = nil
        cursor = ""
        seen = []
        emptyLoadCount = 0
        canLoadMore = true
        defer { isLoading = false }

        guard WeiboSession.shared.isLoggedIn else {
            errorMessage = "请先登录微博，才能读取「特别关注」。"
            return
        }

        // 1) 优先从页签解析真实 containerid
        if let resolved = await FeedTabsResolver.shared.homeTab(containing: "特别关注") {
            if await load(containerID: resolved, firstPage: true) { return }
        }

        // 2) 候选容器兜底
        for candidate in WeiboEndpoint.closeFriendCandidates {
            if await load(containerID: candidate, firstPage: true) { return }
        }

        errorMessage = "暂时读不到微博的「特别关注」分组，接口可能已调整。"
    }

    func loadMore() async {
        guard let container = containerID, !isLoading, !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        _ = await load(containerID: container, firstPage: false)
    }

    @discardableResult
    private func load(containerID candidate: String, firstPage: Bool) async -> Bool {
        let since = firstPage ? nil : (cursor.isEmpty ? nil : cursor)
        guard let url = WeiboEndpoint.container(id: candidate, page: 1, sinceID: since) else {
            return false
        }
        guard let response: ContainerResponse = try? await WeiboAPI.shared.get(url) else {
            return false
        }
        guard response.ok == 1, let data = response.data else { return false }

        containerID = candidate

        if firstPage {
            cursor = data.cursor
            let blogs = data.statusCards
            seen = Set(blogs.map { $0.navKey })
            items = blogs
            if blogs.isEmpty {
                errorMessage = "微博「特别关注」里暂时没有内容（也可能分组为空）。"
            }
            CrashTrace.log("special feed \(candidate) count=\(blogs.count) cursor=\(data.cursor)")
            return true
        }

        if !data.cursor.isEmpty { cursor = data.cursor }
        var added: [MBlog] = []
        for blog in data.statusCards where !seen.contains(blog.navKey) {
            seen.insert(blog.navKey)
            added.append(blog)
        }
        if added.isEmpty {
            emptyLoadCount += 1
            if emptyLoadCount >= 2 { canLoadMore = false }
        } else {
            emptyLoadCount = 0
            items.append(contentsOf: added)
        }
        return true
    }
}
