import SwiftUI

struct StatusDetailView: View {
    let mid: String

    @StateObject private var store = DetailStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let status = store.status {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            header(status)
                            if !status.plainText.isEmpty {
                                Text(status.plainText)
                                    .font(.system(size: 17))
                                    .lineSpacing(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
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
        .navigationTitle("微博正文")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(mid: mid) }
    }

    private func header(_ status: MBlog) -> some View {
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

                Text(comment.plainText)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                Text(comment.displayTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
