import SwiftUI
import UIKit

enum Theme {
    static let cardCorner: CGFloat = 18
    static let pagePadding: CGFloat = 12
}

/// 背景：系统底色（浅色=白，深色跟随系统）
struct AppBackground: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }
}

extension View {
    /// 卡片外观（v0.1 同款）：系统毛玻璃材质 + 细描边 + 轻投影。
    /// 系统导航栏 / Tab 栏 / 按钮本身由 iOS 26 自动采用原生 Liquid Glass，
    /// 这里不再手写玻璃，避免"越画越生硬"。
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8))
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        self.glassSurface(Capsule(style: .continuous))
    }
}

/// 统一的信息卡片外观
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
