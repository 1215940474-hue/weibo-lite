import Foundation

enum WeiboAPIError: LocalizedError {
    case badURL
    case http(Int)
    case decode
    case empty
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "链接拼接失败"
        case .http(let code):
            return "网络请求失败（HTTP \(code)）"
        case .decode:
            return "数据解析失败，接口可能已改版"
        case .empty:
            return "接口没有返回内容，可能登录已过期或触发了风控"
        case .notLoggedIn:
            return "还没登录，请先到「我」里登录微博"
        }
    }
}

/// 统一出口：带 Cookie / UA / Referer，并做最低 1 秒的限流。
@MainActor
final class WeiboAPI {
    static let shared = WeiboAPI()

    private let limiter = RateLimiter(minInterval: 1.0)

    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    func get<T: Decodable>(_ url: URL, extraHeaders: [String: String] = [:]) async throws -> T {
        await limiter.wait()

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://m.weibo.cn/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("1", forHTTPHeaderField: "MWeibo-Pwa")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let cookie = WeiboSession.shared.cookieHeader
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        for (key, value) in extraHeaders where !value.isEmpty {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw WeiboAPIError.http(statusCode)
        }
        guard !data.isEmpty else { throw WeiboAPIError.empty }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeiboAPIError.decode
        }
    }
}

/// 串行限流：接口之间至少间隔 minInterval 秒，避免被风控。
actor RateLimiter {
    private let minInterval: TimeInterval
    private var lastRequest: Date = .distantPast

    init(minInterval: TimeInterval) {
        self.minInterval = minInterval
    }

    func wait() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequest)
        if elapsed < minInterval {
            let nanoseconds = UInt64((minInterval - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
        lastRequest = Date()
    }
}

/// m.weibo.cn 网页接口端点（参数/路径以 Flare 的 vvo 模块为准）。
enum WeiboEndpoint {
    /// 个人主页微博列表
    static func userTimelineContainer(uid: String) -> String { "107603\(uid)" }
    /// 搜索微博
    static func searchContainer(keyword: String) -> String { "100103type=1&q=\(keyword)" }
    /// 推荐流（不按时间排序，官方推荐算法）
    static let recommendContainer = "102803"
    /// 热搜榜
    static let hotSearchContainer = "106003type=25&filter_type=realtimehot"

    static func config() -> URL? {
        build(path: "/api/config", items: [])
    }

    /// 关注流：这是真正的时间线接口，max_id 传上一页的 nextCursor
    static func friendsTimeline(maxID: String?) -> URL? {
        var items: [URLQueryItem] = []
        if let maxID = maxID, !maxID.isEmpty {
            items.append(URLQueryItem(name: "max_id", value: maxID))
        }
        return build(path: "/feed/friends", items: items)
    }

    static func container(id: String, page: Int = 1, sinceID: Int64 = 0, pageType: String? = nil) -> URL? {
        var items: [URLQueryItem] = [URLQueryItem(name: "containerid", value: id)]
        if sinceID > 0 {
            items.append(URLQueryItem(name: "since_id", value: String(sinceID)))
        }
        if page > 1 {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let pageType = pageType, !pageType.isEmpty {
            items.append(URLQueryItem(name: "page_type", value: pageType))
        }
        items.append(URLQueryItem(name: "openApp", value: "0"))
        return build(path: "/api/container/getIndex", items: items)
    }

    static func profileInfo(uid: String) -> URL? {
        build(path: "/profile/info", items: [URLQueryItem(name: "uid", value: uid)])
    }

    /// 用户主页容器（拿 userInfo 头像兜底）
    static func userProfileContainer(uid: String) -> URL? {
        build(path: "/api/container/getIndex", items: [
            URLQueryItem(name: "type", value: "uid"),
            URLQueryItem(name: "value", value: uid),
            URLQueryItem(name: "containerid", value: "100505\(uid)")
        ])
    }

    /// 楼中楼回复
    static func commentReplies(cid: String, maxID: String = "0") -> URL? {
        build(path: "/comments/hotFlowChild", items: [
            URLQueryItem(name: "cid", value: cid),
            URLQueryItem(name: "max_id", value: maxID),
            URLQueryItem(name: "max_id_type", value: "0")
        ])
    }

    /// 长文全文
    static func statusExtend(mid: String) -> URL? {
        build(path: "/statuses/extend", items: [URLQueryItem(name: "id", value: mid)])
    }

    static func status(mid: String) -> URL? {
        build(path: "/statuses/show", items: [URLQueryItem(name: "id", value: mid)])
    }

    static func comments(mid: String, maxID: String = "0") -> URL? {
        build(path: "/comments/hotflow", items: [
            URLQueryItem(name: "id", value: mid),
            URLQueryItem(name: "mid", value: mid),
            URLQueryItem(name: "max_id", value: maxID),
            URLQueryItem(name: "max_id_type", value: "0")
        ])
    }

    private static func build(path: String, items: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: "https://m.weibo.cn" + path)
        components?.queryItems = items
        return components?.url
    }
}
