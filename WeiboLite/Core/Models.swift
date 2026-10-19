import Foundation

// MARK: - 容器接口 /api/container/getIndex

struct ContainerResponse: Decodable {
    let ok: Int
    let data: ContainerData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(ContainerData.self, .data)
    }
}

struct ContainerData: Decodable {
    let cards: [Card]
    let sinceID: Int64
    let maxID: Int64
    let userInfo: WBUser?
    /// cardlistInfo.since_id：推荐翻页游标（原样字符串传回）
    let cursor: String

    private enum CodingKeys: String, CodingKey {
        case cards
        case sinceID = "since_id"
        case maxID = "max_id"
        case userInfo
        case cardlistInfo
    }

    private struct CardlistInfo: Decodable {
        let sinceID: String
        private enum CodingKeys: String, CodingKey { case sinceID = "since_id" }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sinceID = container.soft(FlexID.self, .sinceID)?.value ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = container.soft([Card].self, .cards) ?? []
        sinceID = Int64(container.soft(FlexID.self, .sinceID)?.value ?? "") ?? 0
        maxID = Int64(container.soft(FlexID.self, .maxID)?.value ?? "") ?? 0
        userInfo = container.soft(WBUser.self, .userInfo)
        cursor = container.soft(CardlistInfo.self, .cardlistInfo)?.sinceID ?? ""
    }

    /// 只保留真正的微博卡片（card_type == 9），其余（广告位、话题、分组头）全部丢掉。
    var statusCards: [MBlog] {
        cards
            .filter { $0.cardType == 9 }
            .flatMap { $0.allBlogs }
            .filter { !$0.isAd }
    }

    /// 热搜榜条目（containerid=106003type=25&filter_type=realtimehot）
    var hotItems: [HotSearchItem] {
        var result: [HotSearchItem] = []
        for card in cards {
            for group in card.cardGroup {
                let title = group.desc.isEmpty ? (group.mblog?.plainText ?? "") : group.desc
                guard !title.isEmpty else { continue }
                result.append(
                    HotSearchItem(
                        rank: result.count + 1,
                        title: title,
                        heat: group.descExtr
                    )
                )
            }
        }
        return result
    }
}

struct HotSearchItem: Identifiable, Hashable {
    let rank: Int
    let title: String
    let heat: String

    var id: String { "\(rank)-\(title)" }
}

struct Card: Decodable {
    let cardType: Int
    let mblog: MBlog?
    let cardGroup: [Card]
    let desc: String
    let descExtr: String

    private enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
        case mblog
        case cardGroup = "card_group"
        case desc
        case descExtr = "desc_extr"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardType = container.soft(FlexInt.self, .cardType)?.value ?? 0
        mblog = container.soft(MBlog.self, .mblog)
        cardGroup = container.soft([Card].self, .cardGroup) ?? []
        desc = HTMLText.plain(container.soft(String.self, .desc) ?? "")
        descExtr = container.soft(String.self, .descExtr) ?? ""
    }

    var allBlogs: [MBlog] {
        var result: [MBlog] = []
        if cardType == 9, let mblog = mblog { result.append(mblog) }
        for group in cardGroup { result.append(contentsOf: group.allBlogs) }
        return result
    }
}

// MARK: - 单条微博

final class MBlog: Decodable, Identifiable {
    let statusID: String
    let mid: String
    let rawText: String
    let createdAt: String
    let source: String
    let user: WBUser?
    let pics: [WBPic]
    let retweeted: MBlog?
    let commentsCount: Int
    let repostsCount: Int
    let attitudesCount: Int
    let isLongText: Bool
    let isAd: Bool
    /// 视频地址（page_info.type == "video" 时非空）
    let videoURL: String
    /// 解析一次就缓存，滚动时不再重复做正则/日期计算（性能关键）
    let plainText: String
    let displayTime: String

    var id: String { statusID.isEmpty ? mid : statusID }
    /// 用于导航/请求详情的 id（m.weibo.cn 用 mid）
    var navKey: String { mid.isEmpty ? id : mid }

    private enum CodingKeys: String, CodingKey {
        case statusID = "id"
        case mid
        case rawText = "text"
        case createdAt = "created_at"
        case source
        case user
        case pics
        case retweeted = "retweeted_status"
        case commentsCount = "comments_count"
        case repostsCount = "reposts_count"
        case attitudesCount = "attitudes_count"
        case isLongText
        case isAd = "is_ad"
        case promotion
        case pageInfo = "page_info"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statusID = container.soft(FlexID.self, .statusID)?.value ?? ""
        mid = container.soft(FlexID.self, .mid)?.value ?? ""
        rawText = container.soft(String.self, .rawText) ?? ""
        createdAt = container.soft(String.self, .createdAt) ?? ""
        plainText = HTMLText.plain(rawText)
        displayTime = ChineseDate.display(createdAt)
        source = HTMLText.plain(container.soft(String.self, .source) ?? "")
        user = container.soft(WBUser.self, .user)
        pics = container.soft([WBPic].self, .pics) ?? []
        retweeted = container.soft(MBlog.self, .retweeted)
        commentsCount = container.soft(FlexInt.self, .commentsCount)?.value ?? 0
        repostsCount = container.soft(FlexInt.self, .repostsCount)?.value ?? 0
        attitudesCount = container.soft(FlexInt.self, .attitudesCount)?.value ?? 0
        isLongText = container.soft(Bool.self, .isLongText) ?? false

        let hasPromotionKey = container.contains(.promotion)
        let promotionIsNil = (try? container.decodeNil(forKey: .promotion)) ?? true
        let hasPromotion = hasPromotionKey && !promotionIsNil
        let adFlag = (container.soft(FlexInt.self, .isAd)?.value ?? 0) == 1
        isAd = hasPromotion || adFlag
        videoURL = container.soft(PageInfo.self, .pageInfo)?.bestVideoURL ?? ""
    }
}

// MARK: - 用户

struct WBUser: Decodable, Hashable {
    let uid: String
    let screenName: String
    let avatarURL: URL?
    let verified: Bool

    private enum CodingKeys: String, CodingKey {
        case uid = "id"
        case screenName = "screen_name"
        case avatarLarge = "avatar_large"
        case avatar = "profile_image_url"
        case verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = container.soft(FlexID.self, .uid)?.value ?? ""
        screenName = container.soft(String.self, .screenName) ?? "微博用户"
        let rawAvatar = container.soft(String.self, .avatarLarge)
            ?? container.soft(String.self, .avatar)
            ?? ""
        avatarURL = URL(string: rawAvatar.replacingOccurrences(of: "http://", with: "https://"))
        verified = container.soft(Bool.self, .verified) ?? false
    }
}

// MARK: - 配图

struct WBPic: Decodable, Hashable {
    let largeURL: String
    let fallbackURL: String

    var url: URL? {
        let raw = largeURL.isEmpty ? fallbackURL : largeURL
        return URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
    }

    private enum CodingKeys: String, CodingKey { case large, url }
    private struct PicURL: Decodable {
        let url: String
        private enum CodingKeys: String, CodingKey { case url }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            url = container.soft(String.self, .url) ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        largeURL = container.soft(PicURL.self, .large)?.url ?? ""
        fallbackURL = container.soft(String.self, .url) ?? ""
    }
}

// MARK: - 详情 /api/statuses/show

struct StatusShowResponse: Decodable {
    let ok: Int
    let data: MBlog?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(MBlog.self, .data)
    }
}

// MARK: - 评论 /api/comments/hotflow

struct CommentsResponse: Decodable {
    let ok: Int
    let data: CommentData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(CommentData.self, .data)
    }
}

struct CommentData: Decodable {
    let comments: [WBComment]
    let maxID: String

    private enum CodingKeys: String, CodingKey {
        case comments = "data"
        case maxID = "max_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comments = container.soft([WBComment].self, .comments) ?? []
        maxID = container.soft(FlexID.self, .maxID)?.value ?? ""
    }
}

struct WBComment: Decodable, Identifiable {
    let cid: String
    let text: String
    let createdAt: String
    let likeCounts: Int
    let replyCount: Int
    let user: WBUser?

    var id: String { cid }
    var rawHTML: String { text }
    var plainText: String { HTMLText.plain(text) }
    var displayTime: String { ChineseDate.display(createdAt) }

    private enum CodingKeys: String, CodingKey {
        case cid = "id"
        case text
        case createdAt = "created_at"
        case likeCounts = "like_counts"
        case replyCount = "total_number"
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cid = container.soft(FlexID.self, .cid)?.value ?? UUID().uuidString
        text = container.soft(String.self, .text) ?? ""
        createdAt = container.soft(String.self, .createdAt) ?? ""
        likeCounts = container.soft(FlexInt.self, .likeCounts)?.value ?? 0
        replyCount = container.soft(FlexInt.self, .replyCount)?.value ?? 0
        user = container.soft(WBUser.self, .user)
    }
}

// MARK: - 登录态 /api/config

struct ConfigResponse: Decodable {
    let ok: Int
    let data: ConfigData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(ConfigData.self, .data)
    }
}

struct ConfigData: Decodable {
    let uid: String
    let user: WBUser?
    let st: String

    private enum CodingKeys: String, CodingKey { case uid, user, st }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = container.soft(FlexID.self, .uid)?.value ?? ""
        user = container.soft(WBUser.self, .user)
        st = container.soft(String.self, .st) ?? ""
    }
}

// MARK: - 关注流 /feed/friends

struct FriendsTimelineResponse: Decodable {
    let ok: Int
    let data: FriendsTimelineData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(FriendsTimelineData.self, .data)
    }
}

struct FriendsTimelineData: Decodable {
    let statuses: [MBlog]
    let nextCursor: String

    private enum CodingKeys: String, CodingKey {
        case statuses
        case nextCursorStr
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statuses = container.soft([MBlog].self, .statuses) ?? []
        nextCursor = container.soft(String.self, .nextCursorStr)
            ?? container.soft(FlexID.self, .nextCursor)?.value
            ?? ""
    }
}

// MARK: - 个人资料 /profile/info

struct ProfileResponse: Decodable {
    let ok: Int
    let data: ProfileInfoData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(ProfileInfoData.self, .data)
    }
}

struct ProfileInfoData: Decodable {
    let userInfo: WBUser?

    private enum CodingKeys: String, CodingKey {
        case userInfo
        case userInfoSnake = "user_info"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userInfo = container.soft(WBUser.self, .userInfo)
            ?? container.soft(WBUser.self, .userInfoSnake)
    }
}

// MARK: - 视频 page_info

/// 字典里可能是字符串、也可能是对象，统一按字符串兜底
struct FlexString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
}

struct MediaInfo: Decodable {
    let streamURL: String
    let streamURLHD: String
    let mp4HD: String
    let mp4720: String

    private enum CodingKeys: String, CodingKey {
        case streamURL = "stream_url"
        case streamURLHD = "stream_url_hd"
        case mp4HD = "mp4_hd_url"
        case mp4720 = "mp4_720p_mp4"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamURL = container.soft(String.self, .streamURL) ?? ""
        streamURLHD = container.soft(String.self, .streamURLHD) ?? ""
        mp4HD = container.soft(String.self, .mp4HD) ?? ""
        mp4720 = container.soft(String.self, .mp4720) ?? ""
    }
}

struct PageInfo: Decodable {
    let type: String
    let pageURL: String
    let mediaInfo: MediaInfo?
    let urls: [String: FlexString]

    private enum CodingKeys: String, CodingKey {
        case type
        case pageURL = "page_url"
        case mediaInfo = "media_info"
        case urls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.soft(String.self, .type) ?? ""
        pageURL = container.soft(String.self, .pageURL) ?? ""
        mediaInfo = container.soft(MediaInfo.self, .mediaInfo)
        urls = container.soft([String: FlexString].self, .urls) ?? [:]
    }

    /// 视频地址优先级：1080p → 720p → hd → sd → stream（尽量最高画质）
    var bestVideoURL: String {
        for key in ["mp4_1080p_mp4", "mp4_2160p_mp4", "mp4_720p_mp4", "mp4_hd_url", "mp4_sd_url"] {
            if let value = urls[key]?.value, !value.isEmpty {
                return value
            }
        }
        if let info = mediaInfo {
            for candidate in [info.mp4720, info.mp4HD, info.streamURLHD, info.streamURL] where !candidate.isEmpty {
                return candidate
            }
        }
        return ""
    }
}

// MARK: - 楼中楼回复 /comments/hotFlowChild

struct CommentRepliesResponse: Decodable {
    let ok: Int
    let replies: [WBComment]

    private enum CodingKeys: String, CodingKey {
        case ok
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        replies = container.soft([WBComment].self, .data) ?? []
    }
}

// MARK: - 长文全文 /statuses/extend

struct StatusExtendResponse: Decodable {
    let ok: Int
    let data: StatusExtendData?

    private enum CodingKeys: String, CodingKey { case ok, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.soft(FlexInt.self, .ok)?.value ?? 0
        data = container.soft(StatusExtendData.self, .data)
    }
}

struct StatusExtendData: Decodable {
    let longTextContent: String

    private enum CodingKeys: String, CodingKey {
        case longTextContent
        case longTextContentSnake = "longTextContentRaw"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        longTextContent = container.soft(String.self, .longTextContent)
            ?? container.soft(String.self, .longTextContentSnake)
            ?? ""
    }
}
