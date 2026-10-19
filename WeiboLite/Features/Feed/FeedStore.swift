import Combine
import Foundation

/// 通用信息流数据源：推荐、关注流、用户主页、搜索结果。
@MainActor
final class FeedStore: ObservableObject {
    enum Source: Equatable {
        case recommend
        case following
        case user(uid: String)
        case search(keyword: String)
    }

    @Published private(set) var items: [MBlog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = true

    private let source: Source
    private var page = 1
    private var followingCursor = ""
    /// 推荐流翻页游标（cardlistInfo.since_id，字符串原样传回）
    private var recommendCursor = ""
    private var seen: Set<String> = []
    private var emptyLoadCount = 0

    init(source: Source) {
        self.source = source
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        page = 1
        followingCursor = ""
        recommendCursor = ""
        emptyLoadCount = 0
        canLoadMore = true
        defer { isLoading = false }

        do {
            let blogs = try await fetch(isFirst: true)
            seen = Set(blogs.map { $0.navKey })
            items = blogs
            if blogs.isEmpty {
                errorMessage = emptyHint
            }
        } catch {
            errorMessage = describe(error)
        }
    }

    func loadMore() async {
        guard !isLoading, !isLoadingMore, !items.isEmpty, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let blogs = try await fetch(isFirst: false)
            var added: [MBlog] = []
            for blog in blogs where !seen.contains(blog.navKey) {
                seen.insert(blog.navKey)
                added.append(blog)
            }
            // 有内容才推进页码，避免接口失败后一直空转
            if !blogs.isEmpty, case .search = source {
                page += 1
            } else if !blogs.isEmpty, case .user = source {
                page += 1
            }
            if added.isEmpty {
                // 连续两页没有新内容就停止上拉，避免死循环请求
                emptyLoadCount += 1
                if emptyLoadCount >= 2 {
                    canLoadMore = false
                }
            } else {
                emptyLoadCount = 0
            }
            items.append(contentsOf: added)
        } catch {
            errorMessage = describe(error)
        }
    }

    // MARK: - 网络

    private func fetch(isFirst: Bool) async throws -> [MBlog] {
        switch source {
        case .recommend:
            return try await fetchRecommend(isFirst: isFirst)
        case .following:
            return try await fetchFollowing(maxID: isFirst ? nil : followingCursor)
        case .user(let uid):
            return try await fetchContainer(
                id: WeiboEndpoint.userTimelineContainer(uid: uid),
                page: isFirst ? 1 : page,
                pageType: nil
            )
        case .search(let keyword):
            return try await fetchContainer(
                id: WeiboEndpoint.searchContainer(keyword: keyword),
                page: isFirst ? 1 : page,
                pageType: "searchall"
            )
        }
    }

    /// 推荐流：102803 容器，优先用 since_id 游标翻页
    private func fetchRecommend(isFirst: Bool) async throws -> [MBlog] {
        if !isFirst, recommendCursor.isEmpty { page += 1 }
        guard let url = WeiboEndpoint.container(
            id: WeiboEndpoint.recommendContainer,
            page: recommendCursor.isEmpty ? (isFirst ? 1 : page) : 1,
            sinceID: recommendCursor.isEmpty ? nil : recommendCursor
        ) else {
            throw WeiboAPIError.badURL
        }
        let response: ContainerResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        if !data.cursor.isEmpty {
            recommendCursor = data.cursor
        }
        return data.statusCards
    }

    /// 真正的关注时间线：/feed/friends，按 max_id 游标翻页
    private func fetchFollowing(maxID: String?) async throws -> [MBlog] {
        guard WeiboSession.shared.isLoggedIn else {
            throw WeiboAPIError.notLoggedIn
        }
        guard let url = WeiboEndpoint.friendsTimeline(maxID: maxID) else {
            throw WeiboAPIError.badURL
        }
        let response: FriendsTimelineResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        followingCursor = data.nextCursor
        return data.statuses.filter { !$0.isAd }
    }

    private func fetchContainer(id: String, page: Int, pageType: String?) async throws -> [MBlog] {
        guard let url = WeiboEndpoint.container(id: id, page: page, pageType: pageType) else {
            throw WeiboAPIError.badURL
        }
        let response: ContainerResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        return data.statusCards
    }

    // MARK: - 提示文案

    private var emptyHint: String {
        switch source {
        case .recommend:
            return "推荐流没有内容，下拉刷新重试。"
        case .following:
            return "关注流没有内容。先确认已登录，或下拉刷新重试。"
        case .user:
            return "这个用户没有可见微博。"
        case .search:
            return "没有搜到相关微博。"
        }
    }

    private func describe(_ error: Error) -> String {
        if let apiError = error as? WeiboAPIError {
            return apiError.errorDescription ?? "未知错误"
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "网络连接失败，检查一下网络或稍后再试。"
        }
        return error.localizedDescription
    }
}
