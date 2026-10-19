import Combine
import Foundation

@MainActor
final class DetailStore: ObservableObject {
    @Published private(set) var status: MBlog?
    @Published private(set) var comments: [WBComment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(mid: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let statusURL = WeiboEndpoint.status(mid: mid) else {
                throw WeiboAPIError.badURL
            }
            let response: StatusShowResponse = try await WeiboAPI.shared.get(statusURL)
            guard response.ok == 1, let blog = response.data else {
                throw WeiboAPIError.empty
            }
            status = blog
            comments = await loadComments(mid: mid)
        } catch {
            if let apiError = error as? WeiboAPIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadComments(mid: String) async -> [WBComment] {
        guard let url = WeiboEndpoint.comments(mid: mid) else { return [] }
        do {
            let response: CommentsResponse = try await WeiboAPI.shared.get(url)
            return response.data?.comments ?? []
        } catch {
            // 评论加载失败不影响正文展示
            return []
        }
    }
}
