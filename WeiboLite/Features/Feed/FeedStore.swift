import Combine
import Foundation

/// 通用信息流数据源：推荐流 / 关注流 / 用户主页 / 搜索结果 共用。
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

    private let source: Source
    private var page = 1
    private var sinceID: Int64 = 0
    private var seen: Set<String> = []

    init(source: Source) {
        self.source = source
    }

    var isEmpty: Bool { items.isEmpty }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        page = 1
        sinceID = 0
        defer { isLoading = false }

        do {
            let blogs = try await fetch(page: 1, sinceID: 0)
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
        guard !isLoading, !isLoadingMore, !items.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = page + 1
        do {
            let blogs = try await fetch(page: nextPage, sinceID: sinceID)
            page = nextPage
            var added: [MBlog] = []
            for blog in blogs where !seen.contains(blog.navKey) {
                seen.insert(blog.navKey)
                added.append(blog)
            }
            items.append(contentsOf: added)
        } catch {
            errorMessage = describe(error)
        }
    }

    // MARK: - 网络

    private func fetch(page: Int, sinceID: Int64) async throws -> [MBlog] {
        switch source {
        case .recommend:
            return try await loadContainer(id: WeiboEndpoint.recommendContainer, sinceID: sinceID, page: 1)
        case .following:
            return try await loadContainer(id: WeiboEndpoint.followingContainer, sinceID: sinceID, page: 1)
        case .user(let uid):
            return try await loadContainer(id: "107603\(uid)", sinceID: 0, page: page)
        case .search(let keyword):
            return try await loadContainer(id: "100103type=1&q=\(keyword)", sinceID: 0, page: page)
        }
    }

    private func loadContainer(id: String, sinceID: Int64, page: Int) async throws -> [MBlog] {
        guard let url = WeiboEndpoint.container(id: id, sinceID: sinceID, page: page) else {
            throw WeiboAPIError.badURL
        }
        let response: ContainerResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        if data.sinceID > 0 {
            self.sinceID = data.sinceID
        }
        return data.statusCards
    }

    // MARK: - 提示文案

    private var emptyHint: String {
        switch source {
        case .following:
            return "关注流暂时取不到（接口可能已调整）。下拉重试，或切到「推荐」。"
        case .recommend:
            return "没有内容。若未登录，请到「我」里先登录。"
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
