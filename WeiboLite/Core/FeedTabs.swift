import Combine
import Foundation

/// 从微博返回的 `tabsInfo` 里解析真实分组 containerid。
/// 关注 / 特别关注 / 关注列表 / 粉丝列表 的容器 id 都藏在这些页签里，
/// 比硬编码候选值可靠。
@MainActor
final class FeedTabsResolver {
    static let shared = FeedTabsResolver()

    private var homeCache: [FeedTab] = []
    private var profileCache: [String: [FeedTab]] = [:]

    func homeTabs() async -> [FeedTab] {
        if !homeCache.isEmpty { return homeCache }
        guard let url = WeiboEndpoint.container(id: WeiboEndpoint.recommendContainer) else { return [] }
        if let response: ContainerResponse = try? await WeiboAPI.shared.get(url),
           let tabs = response.data?.tabsInfo?.tabs,
           !tabs.isEmpty {
            homeCache = tabs
            CrashTrace.log("home tabs: " + tabs.map { "\($0.title)=\($0.containerID)" }.joined(separator: " | "))
        }
        return homeCache
    }

    func homeTab(containing keyword: String, excluding: [String] = []) async -> String? {
        let tabs = await homeTabs()
        return tabs.first { tab in
            tab.title.contains(keyword)
                && !excluding.contains(where: { tab.title.contains($0) })
        }?.containerID
    }

    func profileTabs(uid: String) async -> [FeedTab] {
        if let cached = profileCache[uid], !cached.isEmpty { return cached }
        guard let url = WeiboEndpoint.userProfileContainer(uid: uid) else { return [] }
        if let response: ContainerResponse = try? await WeiboAPI.shared.get(url),
           let tabs = response.data?.tabsInfo?.tabs,
           !tabs.isEmpty {
            profileCache[uid] = tabs
            CrashTrace.log("profile tabs \(uid): " + tabs.map { "\($0.title)=\($0.containerID)" }.joined(separator: " | "))
        }
        return profileCache[uid] ?? []
    }

    func profileTab(uid: String, containing keyword: String, excluding: [String] = []) async -> String? {
        let tabs = await profileTabs(uid: uid)
        return tabs.first { tab in
            tab.title.contains(keyword)
                && !excluding.contains(where: { tab.title.contains($0) })
        }?.containerID
    }
}
