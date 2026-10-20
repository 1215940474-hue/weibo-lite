import Foundation

/// 截图模式：CI 里用 UI 测试跑界面截图时，用本地假数据渲染，保证稳定、不依赖登录和网络。
enum ScreenshotMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }
}

enum ScreenshotFixtures {
    static var feed: [MBlog] { decode([MBlog].self, feedJSON) ?? [] }
    static var searchResults: [MBlog] { feed }
    static var special: [MBlog] { feed }
    static var comments: [WBComment] { decode([WBComment].self, commentsJSON) ?? [] }
    static var hotItems: [HotSearchItem] {
        let titles = [
            "某地地铁新线路开通首日客流爆满",
            "秋季流感高发 医生提醒这三类人",
            "国产大模型发布 参数规模创新高",
            "高校食堂推出 9.9 元自助餐",
            "新能源车销量同比增长 42%",
            "周末去哪儿 城市周边小众露营地推荐",
            "手机影像新旗舰发布 主打长焦",
            "年轻人开始流行「反向旅游」",
            "这家开了 30 年的面馆要关门了",
            "宠物经济持续升温"
        ]
        return titles.enumerated().map { index, title in
            HotSearchItem(rank: index + 1, title: title, heat: String(1_200_000 - index * 87_000))
        }
    }

    static var followingUsers: [WBUser] { decode([WBUser].self, followingUsersJSON) ?? [] }

    static var user: WBUser? {
        decode(WBUser.self, userJSON)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        try? JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private static let followingUsersJSON = """
    [
      {"id":"3000000001","screen_name":"摄影师老王","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","verified":true,"description":"城市摄影 / 记录光与影"},
      {"id":"3000000002","screen_name":"数据观察","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","verified":true,"description":"用数据看世界"},
      {"id":"3000000003","screen_name":"周末观察员","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","description":"周末去哪里"},
      {"id":"3000000004","screen_name":"深夜食堂","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","description":"一碗面的事"},
      {"id":"3000000005","screen_name":"旅行计划中","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","description":"下一站去哪"}
    ]
    """

    private static let userJSON = """
    {"id":"1234567890","screen_name":"示例用户","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","avatar_large":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","verified":true,"description":"iOS 开发者 / 摄影爱好者 / 记录生活"}
    """

    private static let feedJSON = """
    [
      {
        "id": "4900000000000001",
        "mid": "4900000000000001",
        "text": "今天天气很好，出来走走 <img class=\\"emoji\\" alt=\\"[太阳]\\" src=\\"https://h5.sinaimg.cn/m/emoticon/icon/others/w_taiyang-1d0d4a2b6d.png\\"> 顺便记录一下这条长微博：<br />城市里的树开始变色了，秋天真的来了。路上还遇到一家很有意思的咖啡店，手冲不错。<a href=\\"https://m.weibo.cn/status/4900000000000009\\">网页链接</a>",
        "created_at": "2小时前",
        "source": "iPhone客户端",
        "user": {"id":"1000000001","screen_name":"摄影师老王","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","verified":true},
        "pics": [
          {"pid":"1","url":"https://wx1.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx1.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"2","url":"https://wx1.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx1.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"3","url":"https://wx1.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx1.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}}
        ],
        "comments_count": 128,
        "reposts_count": 456,
        "attitudes_count": 1890,
        "isLongText": false
      },
      {
        "id": "4900000000000002",
        "mid": "4900000000000002",
        "text": "九宫格记录周末：<br />天气、咖啡、猫、书、晚霞，生活碎片。",
        "created_at": "昨天 21:30",
        "source": "微博网页版",
        "user": {"id":"1000000002","screen_name":"周末观察员","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg"},
        "pics": [
          {"pid":"1","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"2","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"3","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"4","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"5","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"6","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"7","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"8","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}},
          {"pid":"9","url":"https://wx2.sinaimg.cn/orj360/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg","large":{"url":"https://wx2.sinaimg.cn/large/006APoFYly1h8k0vb3z4bj30u0140dgp.jpg"}}
        ],
        "comments_count": 32,
        "reposts_count": 12,
        "attitudes_count": 260
      },
      {
        "id": "4900000000000003",
        "mid": "4900000000000003",
        "text": "转发一条：这条内容值得看看。<br />顺便说一句，评论区的讨论也很有意思。",
        "created_at": "今天 09:12",
        "source": "iPhone客户端",
        "user": {"id":"1000000003","screen_name":"路过的网友","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg"},
        "retweeted_status": {
          "id": "4900000000000100",
          "mid": "4900000000000100",
          "text": "原文：一份关于城市通勤时间的调查，平均单程 46 分钟。<a href=\\"https://m.weibo.cn/status/4900000000000101\\">网页链接</a>",
          "created_at": "今天 08:00",
          "user": {"id":"1000000004","screen_name":"数据观察","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg","verified":true},
          "pics": [],
          "comments_count": 88,
          "reposts_count": 500,
          "attitudes_count": 2300
        },
        "pics": [],
        "comments_count": 5,
        "reposts_count": 3,
        "attitudes_count": 41
      },
      {
        "id": "4900000000000004",
        "mid": "4900000000000004",
        "text": "短微博：今天吃了碗面，很香。",
        "created_at": "昨天 12:05",
        "source": "iPhone客户端",
        "user": {"id":"1000000005","screen_name":"深夜食堂","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly1h8k0vb3z4bj30hs0hsdg2.jpg"},
        "pics": [],
        "comments_count": 2,
        "reposts_count": 0,
        "attitudes_count": 8
      }
    ]
    """

    private static let commentsJSON = """
    [
      {"id":"c1","text":"拍得真好，第三张的构图很喜欢！","created_at":"1小时前","like_counts":23,"total_number":2,"user":{"id":"2000000001","screen_name":"摄影爱好者","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg"}},
      {"id":"c2","text":"请问这是哪里？想去看看。<a href=\\"https://m.weibo.cn/status/4900000000000009\\">网页链接</a>","created_at":"2小时前","like_counts":5,"total_number":0,"user":{"id":"2000000002","screen_name":"旅行计划中","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg"}},
      {"id":"c3","text":"秋天真的很适合出门散步。","created_at":"3小时前","like_counts":1,"total_number":0,"user":{"id":"2000000003","screen_name":"散步的人","profile_image_url":"https://tvax1.sinaimg.cn/crop.0.0.180.180.180/006APoFYly8h8k0vb3z4bj30hs0hsdg2.jpg"}}
    ]
    """
}
