import Combine
import Foundation
import WebKit

/// 登录态 = 从 WKWebView 抓到的微博 Cookie（核心是 SUB / SUBP）。
/// 只存本机 UserDefaults，不上传任何地方。
@MainActor
final class WeiboSession: ObservableObject {
    static let shared = WeiboSession()

    @Published private(set) var cookieValues: [String: String] = [:]
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var uid: String = ""
    @Published private(set) var screenName: String = ""
    @Published private(set) var avatarURL: URL?

    private let cookieKey = "weibolite.cookies.v1"
    private let profileKey = "weibolite.profile.v1"

    var cookieHeader: String {
        cookieValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
    }

    private init() {
        loadCookies()
        loadProfile()
    }

    // MARK: - 登录态更新

    func update(cookies: [HTTPCookie]) {
        var dict: [String: String] = [:]
        for cookie in cookies where cookie.domain.contains("weibo.cn") {
            guard !cookie.value.isEmpty else { continue }
            dict[cookie.name] = cookie.value
        }
        guard !dict.isEmpty else { return }

        cookieValues = dict
        isLoggedIn = !(dict["SUB"] ?? "").isEmpty
        persistCookies()

        if isLoggedIn {
            Task { await refreshProfile() }
        }
    }

    func refreshProfile() async {
        guard isLoggedIn else { return }
        guard let url = WeiboEndpoint.config() else { return }
        do {
            let response: ConfigResponse = try await WeiboAPI.shared.get(url)
            guard let data = response.data else { return }
            uid = data.uid
            if let user = data.user {
                screenName = user.screenName
                avatarURL = user.avatarURL
            }
            persistProfile()
            // 接口能返回 uid 说明 Cookie 仍然有效
            if uid.isEmpty { isLoggedIn = false }
        } catch {
            // 网络抖动时保留本地登录态，不把用户踢下线
        }
    }

    func logout() {
        cookieValues = [:]
        isLoggedIn = false
        uid = ""
        screenName = ""
        avatarURL = nil
        UserDefaults.standard.removeObject(forKey: cookieKey)
        UserDefaults.standard.removeObject(forKey: profileKey)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast,
            completionHandler: {}
        )
    }

    // MARK: - 持久化

    private func persistCookies() {
        UserDefaults.standard.set(cookieValues, forKey: cookieKey)
    }

    private func loadCookies() {
        if let dict = UserDefaults.standard.dictionary(forKey: cookieKey) as? [String: String] {
            cookieValues = dict
        }
        isLoggedIn = !(cookieValues["SUB"] ?? "").isEmpty
    }

    private func persistProfile() {
        let dict: [String: String] = [
            "uid": uid,
            "screenName": screenName,
            "avatar": avatarURL?.absoluteString ?? ""
        ]
        UserDefaults.standard.set(dict, forKey: profileKey)
    }

    private func loadProfile() {
        guard let dict = UserDefaults.standard.dictionary(forKey: profileKey) else { return }
        uid = (dict["uid"] as? String) ?? ""
        screenName = (dict["screenName"] as? String) ?? ""
        if let avatar = dict["avatar"] as? String, !avatar.isEmpty {
            avatarURL = URL(string: avatar)
        }
    }
}
