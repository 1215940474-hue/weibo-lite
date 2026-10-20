import SwiftUI

/// 顶部渐进模糊：用一层材质 + 多段渐变遮罩，模拟 iOS 26 的滚动边缘虚化。
struct ProgressiveTopBlur: View {
    var height: CGFloat = 64
    /// 叠加一层底部渐隐，避免材质在浅色背景上出现硬边
    var fadesToBackground: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black.opacity(0.92), location: 0.30),
                            .init(color: .black.opacity(0.55), location: 0.62),
                            .init(color: .black.opacity(0.18), location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if fadesToBackground {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground).opacity(0.9),
                        Color(uiColor: .systemBackground).opacity(0.35),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

/// 一级/二级页面通用顶部栏：标题 + 渐进模糊，内容从下面滚过
struct GlassPageHeader<Trailing: View>: View {
    let title: String
    var height: CGFloat = 84
    var showsBack: Bool = false
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ProgressiveTopBlur(height: height)

            HStack(spacing: 6) {
                if showsBack {
                    Button {
                        onBack?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .frame(height: height, alignment: .bottom)
    }
}

extension GlassPageHeader where Trailing == EmptyView {
    init(title: String, height: CGFloat = 84, showsBack: Bool = false, onBack: (() -> Void)? = nil) {
        self.init(title: title, height: height, showsBack: showsBack, onBack: onBack, trailing: { EmptyView() })
    }
}

/// 底部导航栏浮层的背景：一点点模糊，让内容从下面滚过时更"贴"
struct BottomBarBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground).opacity(0),
                Color(uiColor: .systemBackground).opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 26)
        .allowsHitTesting(false)
    }
}
