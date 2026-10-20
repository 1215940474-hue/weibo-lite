import SwiftUI

struct StatusDetailView: View {
    let mid: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = DetailStore()
    @State private var fullTextHTML: String?
    @State private var isExpanded = false
    @State private var isLoadingFullText = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let status = store.status {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            header(status)
                            textSection(status)
                            if !status.videoURL.isEmpty, let videoURL = URL(string: status.videoURL) {
                                WeiboVideoPlayer(url: videoURL)
                            }
                            if !status.pics.isEmpty {
                                TappableImageGrid(pics: status.pics)
                            }
                            if let retweeted = status.retweeted {
                                RepostView(status: retweeted)
                            }
                            counts(status)
                        }
                    }

                    commentsSection
                } else if store.isLoading {
                    ProgressView().padding(.top, 60)
                } else if let message = store.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await store.load(mid: mid) }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .refreshable { await store.load(mid: mid) }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassPageHeader(title: "微博正文", showsBack: true, onBack: { dismiss() })
        }
        .task { await store.load(mid: mid) }
    }

    private func textSection(_ status: MBlog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RichTextView(
                html: fullTextHTML ?? status.rawText,
                font: .system(size: 17),
                fontSize: 17,
                lineSpacing: 5,
                lineLimit: isExpanded ? nil : 10
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if (status.isLongText || status.plainText.count > 300) && !isExpanded {
                Button {
                    loadFullText(status)
                } label: {
                    HStack(spacing: 3) {
                        Text("全文")
                        if isLoadingFullText {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadFullText(_ status: MBlog) {
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

    @ViewBuilder
    private func header(_ status: MBlog) -> some View {
        if let uid = status.user?.uid, !uid.isEmpty {
            NavigationLink(value: UserRoute(uid: uid)) {
                headerContent(status)
            }
            .buttonStyle(.plain)
        } else {
            headerContent(status)
        }
    }

    private func headerContent(_ status: MBlog) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: status.user?.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(status.user?.screenName ?? "微博用户")
                        .font(.headline)
                    if status.user?.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(status.displayTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func counts(_ status: MBlog) -> some View {
        HStack(spacing: 22) {
            CountLabel(icon: "arrow.2.squarepath", count: status.repostsCount)
            CountLabel(icon: "bubble.right", count: status.commentsCount)
            CountLabel(icon: "hand.thumbsup", count: status.attitudesCount)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("热门评论")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.comments.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            ForEach(store.comments) { comment in
                CommentRow(comment: comment)
            }
        }
    }
}

struct CommentRow: View {
    let comment: WBComment

    @State private var replies: [WBComment] = []
    @State private var isLoadingReplies = false
    @State private var expanded = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AvatarView(url: comment.user?.avatarURL, size: 28)
                    Text(comment.user?.screenName ?? "微博用户")
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    CountLabel(icon: "hand.thumbsup", count: comment.likeCounts)
                }

                RichTextView(html: comment.rawHTML, font: .system(size: 15), fontSize: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Text(comment.displayTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if comment.replyCount > 0 {
                        Button {
                            toggleReplies()
                        } label: {
                            Text(expanded ? "收起回复" : "查看 \(comment.replyCount) 条回复")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if expanded {
                    if isLoadingReplies {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 36)
                    } else if replies.isEmpty {
                        Text("暂无回复")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 36)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(replies) { reply in
                                ReplyRow(comment: reply)
                            }
                        }
                        .padding(.leading, 36)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func toggleReplies() {
        if expanded {
            expanded = false
            return
        }
        expanded = true
        guard replies.isEmpty else { return }

        isLoadingReplies = true
        Task {
            defer { isLoadingReplies = false }
            guard let url = WeiboEndpoint.commentReplies(cid: comment.cid) else { return }
            if let response: CommentRepliesResponse = try? await WeiboAPI.shared.get(url) {
                replies = response.replies
            }
        }
    }
}

/// 楼中楼单条回复
struct ReplyRow: View {
    let comment: WBComment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                AvatarView(url: comment.user?.avatarURL, size: 20)
                Text(comment.user?.screenName ?? "微博用户")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(comment.displayTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }

            RichTextView(html: comment.rawHTML, font: .system(size: 14), fontSize: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.6))
        )
    }
}
