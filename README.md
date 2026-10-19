# 微博轻读 WeiboLite

个人自用的 iOS 微博客户端：**无广告**、原生 SwiftUI + iOS 26 Liquid Glass、登录自己的微博账号看关注流。

> ⚠️ 非官方项目，与微博无任何关系。数据来自 `m.weibo.cn` 的**网页接口（非公开 API）**，可能违反微博用户协议，存在账号被限流/异常的风险。**仅供个人自用，不要分发、不要商用、不要上架**（VVebo 当年就是被以「不正当竞争」起诉的）。

---

## 零、零基础 5 步出包（只看这一节就够）

1. 打开 <https://github.com> 注册/登录 → 右上角 `+` → `New repository` → 名字填 `weibo-lite` → 选 **Private** → `Create repository`。
2. 新页面点 `uploading an existing file` → 把电脑上的 `weibo-lite` 文件夹里**所有内容**（含 `.github` 文件夹）拖进网页 → `Commit changes`。
3. 点仓库顶部 `Actions` → 左侧 `Build unsigned IPA` → 右侧 `Run workflow` → 绿色 `Run workflow`。等 3~6 分钟，变成绿色 ✅。
4. 点开这次运行记录 → 页面最下方 `Artifacts` → 下载 `WeiboLite-unsigned-ipa` → 解压得到 `WeiboLite-unsigned.ipa`。
5. 电脑装好 [iTunes](https://www.apple.com/itunes/) 和 [Sideloadly](https://sideloadly.io/)，手机连线 → Sideloadly 里选设备、拖入 IPA、填 Apple ID → `Start`。装完在手机「设置 → 通用 → VPN 与设备管理」里信任证书，并打开「开发者模式」。

> 出错时：把 Actions 日志里以 `error:` 开头的几行发我，我改代码后你再点一次 `Run workflow` 就行。

## 一、功能（v0.1）

| 模块 | 说明 |
| --- | --- |
| 登录 | 内置 WKWebView 打开微博登录页，登录后自动抓取 `SUB/SUBP` Cookie 保存到本机 |
| 首页 | 「关注 / 推荐」双信息流，下拉刷新、上拉自动加载 |
| 去广告 | 数据层只解析 `card_type == 9` 的微博卡片，并过滤 `promotion` 推广字段；广告根本进不了列表 |
| 详情 | 正文 + 九宫格图片 + 转发原文 + 热门评论 |
| 搜索 | 按关键词搜微博内容 |
| 我 | 账号信息、重新登录、退出登录、网页模式（接口失效时兜底） |
| UI | 毛玻璃卡片 + 深浅色跟随系统、竖屏；iOS 26 上 Tab 栏/导航栏等系统控件自动是原生液态玻璃 |

**已知限制**：不能发博/评论/点赞（只读）；视频只显示文本；长文可能被截断；关注流的接口容器 id 是社区常用值，微博一改就会失败（失败会提示切到「推荐」）；免费签名 7 天要重签。

---

## 二、技术栈

- SwiftUI（最低 iOS 18.0；卡片用系统毛玻璃保证任何 Xcode 都能编译，系统控件在 iOS 26 上自动采用液态玻璃）
- WKWebView 登录取 Cookie，URLSession 直连 `m.weibo.cn` 网页接口
- 零第三方依赖（不用 CocoaPods / SPM）
- 工程用 **XcodeGen**（`project.yml`）声明，`WeiboLite.xcodeproj` 由 CI 生成，不入库
- CI：GitHub Actions `macos-15` 编译 → 未签名 IPA

---

## 三、目录结构

```
weibo-lite/
├── project.yml                        # XcodeGen 工程描述
├── .github/workflows/build-ipa.yml    # 云端编译 + 打包 IPA
├── WeiboLite/
│   ├── App/                           # 入口、根视图、Tab
│   ├── Core/                          # 模型、HTTP、Cookie 会话、玻璃样式、通用组件
│   └── Features/
│       ├── Login/                     # WebView 登录
│       ├── Feed/                      # 信息流 + 微博卡片
│       ├── Detail/                    # 详情 + 评论
│       ├── Search/                    # 搜索
│       ├── Me/                        # 我 / 设置
│       └── Web/                       # 网页模式兜底
└── Support/Info.plist                 # 由 XcodeGen 生成（已 gitignore）
```

---

## 四、从 Windows 到 iPhone 的完整流程

> 你没有 Mac，全程不需要 Mac。编译在 GitHub 的 macOS 机器上跑，签名在 Windows 上用 Sideloadly 做。

### Step 0　准备清单

| 需要 | 说明 |
| --- | --- |
| GitHub 账号 | 免费即可。私有仓库也能跑 Actions（免费额度 2000 分钟/月，macOS 按 10 倍计 ≈ 200 分钟，够跑几十次） |
| [GitHub Desktop](https://desktop.github.com/) | Windows 上最省事的上传代码方式（也可以装 Git for Windows 用命令行） |
| Apple ID | 用于免费签名（7 天有效） |
| [iTunes](https://www.apple.com/itunes/) 或 [Apple Devices](https://apps.microsoft.com/detail/9np83lwlpz9k) | Sideloadly 需要它装驱动 |
| [Sideloadly](https://sideloadly.io/) | Windows 上签名 + 安装 IPA |
| 数据线 + iPhone | 首次安装必须连线 |

### Step 1　把代码传到 GitHub

1. 打开 GitHub Desktop → `File` → `Add local repository…` → 选择本目录 `weibo-lite`。
2. 提示 "not a Git repository" 时点 `create a repository`，名字随意（如 `weibo-lite`），点 **Create repository**。
3. 右上角 `Publish repository`，**勾选 Keep this code private**，发布。

### Step 2　触发云端编译

- 上传后会自动触发一次（workflow 监听 `push` 到 `main`）；
- 也可以手动：仓库页 → `Actions` → 左侧 `Build unsigned IPA` → 右上 `Run workflow`。
- 一次构建约 3~6 分钟。成功后 job 页面底部会出现 artifact：**`WeiboLite-unsigned-ipa`**（内含 `WeiboLite-unsigned.ipa`）。

### Step 3　下载 IPA（三选一）

1. **浏览器**：进入那次成功的 run → 页面最下方 `Artifacts` → 点 `WeiboLite-unsigned-ipa` 下载 zip → 解压得到 `.ipa`。
2. **GitHub CLI**（Windows 装 [gh](https://cli.github.com/)）：
   ```
   gh auth login
   gh run download -R <你的用户名>/weibo-lite -n WeiboLite-unsigned-ipa
   ```
3. **nightly.link**：把 `https://nightly.link/<用户名>/weibo-lite/workflows/build-ipa/main/WeiboLite-unsigned-ipa.zip` 粘到浏览器即可下载（无需登录，跑过一次之后可用）。

### Step 4　Sideloadly 签名安装

1. 电脑装 iTunes（Microsoft Store 版也行），确保 iPhone 能被识别。
2. 打开 Sideloadly → iPhone 用数据线连电脑，顶部选中你的设备。
3. 把 `WeiboLite-unsigned.ipa` 拖到 Sideloadly 的 IPA 框里。
4. `Apple account` 填你的 Apple ID。
5. 点 **Start**，按提示输入密码；如果开了双重认证，去 <https://appleid.apple.com> → 登录与安全 → **App 专用密码**，生成一个填进去。
6. 等待提示 `Done`。

### Step 5　手机上信任 + 开发者模式

1. 首次打开会提示「不受信任的开发者」→ 设置 → 通用 → **VPN 与设备管理** → 信任你的 Apple ID 证书。
2. iOS 16 及以上还需要：设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启手机。

### Step 6　7 天后重签

免费 Apple ID 签名的 App **7 天过期**（过期后打不开，重签后数据一般还在）。到期重复 Step 3~5 即可，或改用 [AltStore](https://altstore.io/) + AltServer(Windows) 在同一 Wi-Fi 下自动续签。

> 想彻底免掉 7 天限制：加入 Apple Developer Program（$99/年），用 Sideloadly 选付费账号签名，有效期 1 年。

---

## 五、首次使用

1. 打开 App → 自动弹出登录页 → 用微博账号登录 → 登录成功后自动关闭。
2. 首页默认在「推荐」；切到「关注」看关注流。下拉刷新、上拉加载。
3. 点任意微博进详情看评论；左上角返回。
4. 如果接口报错：去「我」→ 重新登录；仍不行就用「网页模式」。

---

## 六、常见问题

### CI 构建失败

| 报错 | 处理 |
| --- | --- |
| `xcodegen: command not found` | workflow 里已经 `brew install xcodegen`，重跑即可 |
| 想启用卡片原生液态玻璃 | 现在卡片用的是 `ultraThinMaterial`（保证能编译）。跑通后按 `Core/LiquidGlass.swift` 里注释的 3 行替换，并把 `project.yml` 的 `deploymentTarget` 改成 `"26.0"` |
| `No scheme named "WeiboLite"` | `project.yml` 的 `name` / target 名 / schemes 名必须一致 |
| 归档时报签名错误 | 确认 `xcodebuild` 参数里带 `CODE_SIGNING_ALLOWED=NO` |
| `Multiple commands produce Info.plist` | `Support/Info.plist` 不要放进 `sources` 目录（当前配置已避开） |

### App 内

| 现象 | 处理 |
| --- | --- |
| 首页一直转圈 / 空白 | 先确认已登录；下拉刷新；退出重进 |
| 提示「接口返回失败」 | Cookie 过期 → 重新登录；或微博风控 → 等一会儿、降低刷新频率 |
| 关注流拿不到 | 容器 id 变了，切到「推荐」；想要修复需要抓一次 m.weibo.cn 网页请求替换 `WeiboEndpoint.followingContainer` |
| 登录页白屏 | 检查网络；微博登录页偶尔需要重试 |

---

## 七、想改哪里

| 想改 | 位置 |
| --- | --- |
| App 名称 | `project.yml` → `CFBundleDisplayName` |
| Bundle ID（建议改成你自己的唯一值） | `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` |
| 接口端点 / 限流间隔 | `WeiboLite/Core/WeiboAPI.swift` |
| 去广告规则 | `WeiboLite/Core/Models.swift` 的 `ContainerData.statusCards` |
| 卡片外观 / 玻璃效果 | `WeiboLite/Features/Feed/StatusCardView.swift`、`Core/LiquidGlass.swift` |
| 网页模式隐藏广告的 JS | `WeiboLite/Features/Web/WebModeView.swift` |

---

## 八、后续可加（v0.2 候选）

- 发博 / 评论 / 点赞（需要复用网页接口的 POST + `X-XSRF-TOKEN`，风控更严）
- 视频与 Live Photo 播放
- 长文全文（`/statuses/extend`）
- 图片保存 / 转发菜单
- 多账号、离线缓存、热搜榜

---

## 九、免责声明

本项目仅用于个人学习与自用，不提供任何担保。使用非公开接口可能违反微博用户协议，账号风险自负；请勿传播安装包或用于商业用途。
