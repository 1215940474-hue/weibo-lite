import Foundation

enum WeiboAPIError: LocalizedError {
    case badURL
    case http(Int)
    case decode
    case empty

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
        }
    }
}

/// 统一出口：带 Cookie / UA / Referer，并做最低 1 秒的限流。
@MainActor
final class WeiboAPI {
    static let shared = WeiboAPI()

    private let limiter = RateLimiter(minInterval: 1.0)

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    func get<T: Decodable>(_ url: URL) async throws -> T {
        await limiter.wait()

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://m.weibo.cn/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let cookie = WeiboSession.shared.cookieHeader
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
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

/// m.weibo.cn 网页接口端点。
enum WeiboEndpoint {
    /// 首页「推荐」
    static let recommendContainer = "102803"
    /// 首页「关注」（接口偶尔调整，失败时上层会提示切到推荐）
    static let followingContainer = "102803_ctg1_1199_-_ctg1_1199_home"

    static func config() -> URL? {
        build(path: "/api/config", items: [])
    }

    static func container(id: String, sinceID: Int64 = 0, page: Int = 1) -> URL? {
        var items: [URLQueryItem] = [URLQueryItem(name: "containerid", value: id)]
        if sinceID > 0 {
            items.append(URLQueryItem(name: "since_id", value: String(sinceID)))
        }
        if page > 1 {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        items.append(URLQueryItem(name: "openApp", value: "0"))
        return build(path: "/api/container/getIndex", items: items)
    }

    static func userTimeline(uid: String, page: Int = 1) -> URL? {
        container(id: "107603\(uid)", page: page)
    }

    static func search(keyword: String, page: Int = 1) -> URL? {
        container(id: "100103type=1&q=\(keyword)", page: page)
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
