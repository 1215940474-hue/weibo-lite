import SwiftUI
import UIKit

enum Theme {
    static let cardCorner: CGFloat = 22
    static let pagePadding: CGFloat = 12
}

/// 背景：系统底色 + 一层很淡的渐变，配合毛玻璃卡片。
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.purple.opacity(0.07),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// 玻璃外观。
    ///
    /// 现在用的是系统毛玻璃 `ultraThinMaterial`：任何 Xcode / iOS SDK 都能编译，
    /// 视觉上也接近 iOS 26 的玻璃质感，保证第一次 CI 构建就能通过。
    ///
    /// 等 App 跑通、想在卡片上启用「原生 Liquid Glass」时，把下面 3 行换成：
    ///
    ///     if #available(iOS 26.0, *) {
    ///         self.glassEffect(.regular, in: shape)
    ///     } else {
    ///         self.background(.ultraThinMaterial, in: shape)
    ///     }
    ///
    /// 并把 project.yml 里的 deploymentTarget 改成 "26.0"。
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        self.glassSurface(Capsule(style: .continuous))
    }
}

/// 统一的信息卡片外观。
struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .glassSurface(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }
}
