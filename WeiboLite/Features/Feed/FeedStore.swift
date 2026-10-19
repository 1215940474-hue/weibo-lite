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
    /// 当前已经成功加载到的页码（搜索/用户主页用）
    private var page = 1
    private var followingCursor = ""
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
        CrashTrace.log("feed reload start \(source)")
        defer { isLoading = false }

        do {
            let blogs = try await fetchFirst()
            CrashTrace.log("feed reload ok \(source) count=\(blogs.count)")
            seen = Set(blogs.map { $0.navKey })
            items = blogs
            if blogs.isEmpty {
                errorMessage = emptyHint
            }
        } catch {
            CrashTrace.log("feed reload fail \(source) \(error)")
            errorMessage = describe(error)
        }
    }

    func loadMore() async {
        guard !isLoading, !isLoadingMore, !items.isEmpty, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let blogs = try await fetchNext()
            var added: [MBlog] = []
            for blog in blogs where !seen.contains(blog.navKey) {
                seen.insert(blog.navKey)
                added.append(blog)
            }
            if added.isEmpty {
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

    private func fetchFirst() async throws -> [MBlog] {
        switch source {
        case .recommend:
            return try await fetchRecommend(isFirst: true)
        case .following:
            return try await fetchFollowing(maxID: nil)
        case .user(let uid):
            return try await fetchContainer(
                id: WeiboEndpoint.userTimelineContainer(uid: uid),
                page: 1,
                pageType: nil
            )
        case .search(let keyword):
            return try await fetchContainer(
                id: WeiboEndpoint.searchContainer(keyword: keyword),
                page: 1,
                pageType: "searchall"
            )
        }
    }

    /// 翻页：先把 next 页码算出来再请求（之前是请求完之后才自增，等于每次都在请求上一页）
    private func fetchNext() async throws -> [MBlog] {
        switch source {
        case .following:
            return try await fetchFollowing(maxID: followingCursor)
        case .recommend:
            return try await fetchRecommend(isFirst: false)
        case .user(let uid):
            let nextPage = page + 1
            let blogs = try await fetchContainer(
                id: WeiboEndpoint.userTimelineContainer(uid: uid),
                page: nextPage,
                pageType: nil
            )
            if !blogs.isEmpty { page = nextPage }
            return blogs
        case .search(let keyword):
            let nextPage = page + 1
            let blogs = try await fetchContainer(
                id: WeiboEndpoint.searchContainer(keyword: keyword),
                page: nextPage,
                pageType: "searchall"
            )
            if !blogs.isEmpty { page = nextPage }
            return blogs
        }
    }

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
