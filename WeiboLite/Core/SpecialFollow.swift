import Combine
import Foundation

struct SpecialUser: Codable, Identifiable, Hashable {
    let uid: String
    let name: String
    let avatar: String

    var id: String { uid }
}

/// 「特别关注」名单：本地持久化，用户在博主主页点星标加入
@MainActor
final class SpecialFollowStore: ObservableObject {
    static let shared = SpecialFollowStore()

    @Published private(set) var users: [SpecialUser] = []

    private let key = "weibolite.special.users.v1"

    private init() {
        load()
    }

    func isSpecial(_ uid: String) -> Bool {
        users.contains { $0.uid == uid }
    }

    func toggle(uid: String, name: String, avatar: URL?) {
        guard !uid.isEmpty else { return }
        if let index = users.firstIndex(where: { $0.uid == uid }) {
            users.remove(at: index)
        } else {
            users.append(
                SpecialUser(uid: uid, name: name, avatar: avatar?.absoluteString ?? "")
            )
        }
        save()
        CrashTrace.log("special follow toggled, count=\(users.count)")
    }

    func remove(uid: String) {
        users.removeAll { $0.uid == uid }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SpecialUser].self, from: data) else {
            return
        }
        users = decoded
    }
}

/// 特别关注流：把名单里每个人的主页微博拉下来，按时间合并、去重
@MainActor
final class SpecialFeedStore: ObservableObject {
    @Published private(set) var items: [MBlog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = true

    private var pages: [String: Int] = [:]
    private var emptyLoadCount = 0

    func reload() async {
        guard !isLoading else { return }
        let users = SpecialFollowStore.shared.users
        guard !users.isEmpty else {
            items = []
            errorMessage = "还没有特别关注的人。去任意博主主页点 ★ 加入。"
            return
        }

        isLoading = true
        errorMessage = nil
        pages = [:]
        emptyLoadCount = 0
        canLoadMore = true
        defer { isLoading = false }

        var merged: [MBlog] = []
        for user in users {
            if let blogs = try? await fetch(uid: user.uid, page: 1) {
                merged.append(contentsOf: blogs)
                pages[user.uid] = 1
            }
        }
        items = Self.sorted(merged)
        if items.isEmpty {
            errorMessage = "特别关注的人暂时没有新微博。"
        }
    }

    func loadMore() async {
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        let users = SpecialFollowStore.shared.users
        guard !users.isEmpty else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        var added: [MBlog] = []
        for user in users {
            let next = (pages[user.uid] ?? 1) + 1
            if let blogs = try? await fetch(uid: user.uid, page: next), !blogs.isEmpty {
                pages[user.uid] = next
                added.append(contentsOf: blogs)
            }
        }

        let existing = Set(items.map { $0.navKey })
        let newOnes = added.filter { !existing.contains($0.navKey) }
        if newOnes.isEmpty {
            emptyLoadCount += 1
            if emptyLoadCount >= 2 { canLoadMore = false }
        } else {
            emptyLoadCount = 0
            items = Self.sorted(items + newOnes)
        }
    }

    private func fetch(uid: String, page: Int) async throws -> [MBlog] {
        guard let url = WeiboEndpoint.container(
            id: WeiboEndpoint.userTimelineContainer(uid: uid),
            page: page
        ) else {
            throw WeiboAPIError.badURL
        }
        let response: ContainerResponse = try await WeiboAPI.shared.get(url)
        guard response.ok == 1, let data = response.data else {
            throw WeiboAPIError.empty
        }
        return data.statusCards
    }

    private static func sorted(_ blogs: [MBlog]) -> [MBlog] {
        var seen = Set<String>()
        var unique: [MBlog] = []
        for blog in blogs where !seen.contains(blog.navKey) {
            seen.insert(blog.navKey)
            unique.append(blog)
        }
        return unique.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }
}
