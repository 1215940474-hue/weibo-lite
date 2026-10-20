import SwiftUI

struct MeView: View {
    @EnvironmentObject private var session: WeiboSession
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileCard
                    actionCard
                    aboutCard
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                GlassPageHeader(title: "我")
            }
            .task { await session.refreshProfile() }
            .refreshable { await session.refreshProfile() }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    private var profileCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                AvatarView(url: session.avatarURL, size: 56, fallbackText: session.avatarInitial)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.isLoggedIn ? (session.screenName.isEmpty ? "已登录" : session.screenName) : "未登录")
                        .font(.headline)
                    Text(session.isLoggedIn ? "UID \(session.uid)" : "登录后可看关注流、搜索更完整")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if session.isLoggedIn {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var actionCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                Button {
                    showLogin = true
                } label: {
                    rowLabel(title: session.isLoggedIn ? "重新登录" : "登录微博账号", icon: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, 10)

                NavigationLink {
                    WebModeView()
                } label: {
                    rowLabel(title: "网页模式（接口失效时备用）", icon: "safari")
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, 10)

                if let logURL = CrashTrace.fileURL, FileManager.default.fileExists(atPath: logURL.path) {
                    ShareLink(item: logURL) {
                        rowLabel(title: "导出诊断日志", icon: "doc.text")
                    }
                } else {
                    rowLabel(title: "暂无诊断日志", icon: "doc.text", tint: .secondary)
                }

                if session.isLoggedIn {
                    Divider().padding(.vertical, 10)

                    Button(role: .destructive) {
                        session.logout()
                    } label: {
                        rowLabel(title: "退出登录", icon: "rectangle.portrait.and.arrow.right", tint: .red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var aboutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("关于")
                    .font(.subheadline.weight(.semibold))
                Text("版本 \(AppInfo.version)　·　个人自用构建")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppInfo.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rowLabel(title: String, icon: String, tint: Color = .primary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
            Text(title).font(.subheadline)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .contentShape(Rectangle())
    }
}
