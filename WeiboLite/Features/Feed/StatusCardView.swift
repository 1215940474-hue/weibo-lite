import SwiftUI

/// 单条微博卡片。
struct StatusCardView: View {
    let status: MBlog

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                header

                if !status.plainText.isEmpty {
                    LinkableText(text: status.plainText, font: .system(size: 16), lineSpacing: 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarView(url: status.user?.avatarURL, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(status.user?.screenName ?? "微博用户")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    if status.user?.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
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

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: 22) {
            CountLabel(icon: "arrow.2.squarepath", count: status.repostsCount)
            CountLabel(icon: "bubble.right", count: status.commentsCount)
            CountLabel(icon: "hand.thumbsup", count: status.attitudesCount)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

/// 转发/引用的原微博。
struct RepostView: View {
    let status: MBlog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("@\(status.user?.screenName ?? "微博用户")")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if !status.plainText.isEmpty {
                LinkableText(
                    text: status.plainText,
                    font: .system(size: 15),
                    lineSpacing: 3,
                    lineLimit: 8
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

/// 九宫格配图：单图按真实比例显示，多图九宫格；可点击看大图。
struct ImageGrid: View {
    let pics: [WBPic]
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        let urls = pics.compactMap { $0.url }
        if !urls.isEmpty {
            if urls.count == 1 {
                AdaptiveRemoteImage(url: urls[0])
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(0) }
            } else {
                let columns = urls.count == 4 ? 2 : 3
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
                    spacing: 4
                ) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { item in
                        RemoteImageView(url: item.element, contentMode: .fill)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                            .onTapGesture { onTap?(item.offset) }
                    }
                }
            }
        }
    }
}
