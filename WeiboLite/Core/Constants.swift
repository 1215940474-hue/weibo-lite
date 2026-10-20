import Foundation

extension Notification.Name {
    /// 登录成功后广播，信息流收到后自动刷新
    static let weiboDidLogin = Notification.Name("weibolite.didLogin")
}

enum AppInfo {
    static let version = "0.9.3"
    static let disclaimer = """
    本 App 是非官方个人自用客户端，与微博官方无关。
    数据来自 m.weibo.cn 网页接口，属于未公开接口，
    可能违反微博用户协议，存在账号被限流/异常的风险。
    请勿分发、商用或上架。
    """
}
