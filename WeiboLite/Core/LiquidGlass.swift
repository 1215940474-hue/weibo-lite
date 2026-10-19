import SwiftUI
import UIKit

enum Theme {
    static let cardCorner: CGFloat = 18
    static let pagePadding: CGFloat = 12
}

/// 纯白背景（深色模式跟随系统）
struct AppBackground: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }
}

extension View {
    /// 卡片外观：白底 + 细边框 + 轻阴影。
    /// 想要 iOS 26 原生液态玻璃，把实现换成 `glassEffect(.regular, in: shape)`
    /// 并把 project.yml 的 deploymentTarget 改成 "26.0"。
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        self
            .background(Color(uiColor: .systemBackground), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
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
