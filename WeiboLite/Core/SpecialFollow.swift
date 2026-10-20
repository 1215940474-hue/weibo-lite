import Combine
import Foundation

/// 「特别关注」流：直接读微博自己的特别关注分组（不是你在这个 App 里加的名单）。
///
/// 微博移动端的关注分组没有稳定公开的 id，这里按候选容器逐个探测：
/// 只要某个容器返回 `ok == 1` 就认为找到了，再用 `since_id` 游标翻页。
@MainActor
final class SpecialFeedStore: ObservableObject {
    @Published private(set) var items: [MBlog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = true

    /// 已确认可用的容器 id
    private var containerID: String?
    private var cursor: String = ""
    private var seen: Set<String> = []
    private var emptyLoadCount = 0

    func reload() async {
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

        for candidate in WeiboEndpoint.closeFriendCandidates {
            guard let url = WeiboEndpoint.container(id: candidate) else { continue }
            guard let response: ContainerResponse = try? await WeiboAPI.shared.get(url) else {
                continue
            }
            guard response.ok == 1, let data = response.data else { continue }

            containerID = candidate
            cursor = data.cursor
            let blogs = data.statusCards
            seen = Set(blogs.map { $0.navKey })
            items = blogs
            if blogs.isEmpty {
                errorMessage = "微博「特别关注」里暂时没有内容（也可能分组为空）。"
            }
            CrashTrace.log("special feed container=\(candidate) count=\(blogs.count)")
            return
        }

        errorMessage = "暂时读不到微博的「特别关注」分组，接口可能已调整。"
    }

    func loadMore() async {
        guard let id = containerID, !isLoading, !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        guard let url = WeiboEndpoint.container(
            id: id,
            page: 1,
            sinceID: cursor.isEmpty ? nil : cursor
        ) else { return }

        do {
            let response: ContainerResponse = try await WeiboAPI.shared.get(url)
            guard response.ok == 1, let data = response.data else { return }
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
        } catch {
            errorMessage = "加载更多失败，稍后再试。"
        }
    }
}
