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

    /// 微博网页接口的 XSRF 校验头，取 Cookie 里的 XSRF-TOKEN
    var xsrfToken: String {
        cookieValues["XSRF-TOKEN"] ?? cookieValues["X-XSRF-TOKEN"] ?? ""
    }

    /// 没有头像时显示的占位文字
    var avatarInitial: String {
        let name = screenName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "微" : String(name.prefix(1))
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

    /// 拉取自己的昵称和头像：优先 /profile/info，失败再退回 /api/config
    func refreshProfile() async {
        guard isLoggedIn else { return }

        // 1) 没有 uid 时先取 uid
        if uid.isEmpty {
            if let url = WeiboEndpoint.config() {
                if let response: ConfigResponse = try? await WeiboAPI.shared.get(url),
                   let data = response.data {
                    uid = data.uid
                    apply(user: data.user)
                }
            }
        }

        // 2) 用 uid 拉完整资料（这里才有头像）
        if !uid.isEmpty, let url = WeiboEndpoint.profileInfo(uid: uid) {
            let headers = ["X-Xsrf-Token": xsrfToken]
            if let response: ProfileResponse = try? await WeiboAPI.shared.get(url, extraHeaders: headers),
               let user = response.data?.userInfo {
                apply(user: user)
            }
        }

        // 3) 兜底再试一次 config
        if avatarURL == nil || screenName.isEmpty, let url = WeiboEndpoint.config() {
            if let response: ConfigResponse = try? await WeiboAPI.shared.get(url),
               let data = response.data {
                if uid.isEmpty { uid = data.uid }
                apply(user: data.user)
            }
        }

        persistProfile()
        if uid.isEmpty {
            // 所有接口都拿不到 uid，说明 Cookie 失效了
            isLoggedIn = false
        }
    }

    private func apply(user: WBUser?) {
        guard let user = user else { return }
        if !user.screenName.isEmpty, user.screenName != "微博用户" {
            screenName = user.screenName
        }
        if let avatar = user.avatarURL {
            avatarURL = avatar
        }
        if !user.uid.isEmpty {
            uid = user.uid
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
