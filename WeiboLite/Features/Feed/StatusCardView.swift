import SwiftUI

/// 单条微博卡片：
/// - 头像/昵称 → 个人主页
/// - 正文 → 详情页
/// - 图片/视频/全文按钮各自独立
struct StatusCardView: View {
    let status: MBlog

    @Environment(\.mediaPresenter) private var media: MediaPresenter
    @State private var fullTextHTML: String?
    @State private var isExpanded = false
    @State private var isLoadingFullText = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                header

                NavigationLink(value: status.navKey) {
                    textSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if shouldShowFullButton && !isExpanded {
                    Button {
                        loadFullText()
                    } label: {
                        HStack(spacing: 3) {
                            Text("全文")
                            if isLoadingFullText {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                if !status.videoURL.isEmpty, let videoURL = URL(string: status.videoURL) {
                    WeiboVideoPlayer(url: videoURL)
                }

                if !status.pics.isEmpty {
                    TappableImageGrid(pics: status.pics)
                }

                if let retweeted = status.retweeted {
                    RepostView(status: retweeted)
                }

                footer
            }
        }
        .onAppear {
            CrashTrace.log("card appear \(status.navKey) pics=\(status.pics.count) video=\(status.videoURL.isEmpty ? 0 : 1)")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            if let uid = status.user?.uid, !uid.isEmpty {
                NavigationLink(value: UserRoute(uid: uid)) {
                    AvatarView(url: status.user?.avatarURL, size: 38)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        NavigationLink(value: UserRoute(uid: uid)) {
                            Text(status.user?.screenName ?? "微博用户")
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        if status.user?.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    timeRow
                }
            } else {
                AvatarView(url: status.user?.avatarURL, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.user?.screenName ?? "微博用户")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    timeRow
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var timeRow: some View {
        HStack(spacing: 6) {
            Text(status.displayTime)
            if !status.source.isEmpty {
                Text("来自 \(status.source)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var textSection: some View {
        RichTextView(
            html: fullTextHTML ?? status.rawText,
            font: .system(size: 16),
            fontSize: 16,
            lineSpacing: 4,
            lineLimit: isExpanded ? nil : 6,
            interactiveLinks: false
        )
    }

    private var shouldShowFullButton: Bool {
        status.isLongText || status.plainText.count > 120
    }

    private func loadFullText() {
        guard !isLoadingFullText else { return }
        isLoadingFullText = true
        Task {
            defer { isLoadingFullText = false }
            if let url = WeiboEndpoint.statusExtend(mid: status.navKey),
               let response: StatusExtendResponse = try? await WeiboAPI.shared.get(url),
               let html = response.data?.longTextContent,
               !html.isEmpty {
                fullTextHTML = html
            }
            isExpanded = true
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            CountLabel(icon: "arrow.2.squarepath", count: status.repostsCount)
            CountLabel(icon: "bubble.right", count: status.commentsCount)
            CountLabel(icon: "hand.thumbsup", count: status.attitudesCount)
            Spacer(minLength: 0)
            NavigationLink(value: status.navKey) {
                HStack(spacing: 2) {
                    Text("详情")
                    Image(systemName: "chevron.right").font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

/// 转发/引用的原微博。
struct RepostView: View {
    let status: MBlog
    @Environment(\.mediaPresenter) private var media: MediaPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let uid = status.user?.uid, !uid.isEmpty {
                NavigationLink(value: UserRoute(uid: uid)) {
                    Text("@\(status.user?.screenName ?? "微博用户")")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("@\(status.user?.screenName ?? "微博用户")")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !status.plainText.isEmpty {
                RichTextView(
                    html: status.rawText,
                    font: .system(size: 15),
                    fontSize: 15,
                    lineSpacing: 3,
                    lineLimit: 8,
                    interactiveLinks: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !status.videoURL.isEmpty, let videoURL = URL(string: status.videoURL) {
                WeiboVideoPlayer(url: videoURL)
            }

            if !status.pics.isEmpty {
                TappableImageGrid(pics: status.pics)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        )
    }
}

/// 配图：单图按真实比例；多图正方形九宫格，最多 9 张，超出显示 +N。
struct ImageGrid: View {
    let pics: [WBPic]
    var onTap: ((Int) -> Void)? = nil

    private let maxCount = 9

    var body: some View {
        let urls = pics.compactMap { $0.url }
        if urls.count == 1 {
            AdaptiveRemoteImage(url: WeiboImage.large(urls[0]), maxHeight: 560)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(0) }
        } else if urls.count > 1 {
            let shown = Array(urls.prefix(maxCount))
            let extra = urls.count - shown.count
            let columns = shown.count == 4 ? 2 : 3

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
                spacing: 4
            ) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    SquareImageCell(
                        url: WeiboImage.thumbnail(item.element),
                        overlayText: (extra > 0 && item.offset == shown.count - 1) ? "+\(extra)" : nil
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(item.offset) }
                }
            }
        }
    }
}

private struct SquareImageCell: View {
    let url: URL
    var overlayText: String?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RemoteImageView(url: url, contentMode: .fill)
            }
            .overlay {
                if let overlayText = overlayText {
                    ZStack {
                        Color.black.opacity(0.45)
                        Text(overlayText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
