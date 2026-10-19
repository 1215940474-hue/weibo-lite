import SwiftUI

/// 单条微博卡片。
struct StatusCardView: View {
    let status: MBlog

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                header

                if !status.plainText.isEmpty {
                    Text(status.plainText)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if !status.pics.isEmpty {
                    ImageGrid(pics: status.pics)
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
                    Text(status.createdAt)
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
                Text(status.plainText)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !status.pics.isEmpty {
                ImageGrid(pics: status.pics)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.55))
        )
    }
}

/// 九宫格配图。
struct ImageGrid: View {
    let pics: [WBPic]

    var body: some View {
        let urls = pics.compactMap { $0.url }
        if !urls.isEmpty {
            if urls.count == 1 {
                ImageCell(url: urls[0])
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            } else {
                let columns = urls.count == 4 ? 2 : 3
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
                    spacing: 4
                ) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { item in
                        ImageCell(url: item.element)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

private struct ImageCell: View {
    let url: URL

    var body: some View {
        Color.clear
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
