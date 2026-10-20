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
    /// 卡片 / 胶囊的玻璃外观。
    ///
    /// - Xcode 26（Swift 6.2+，含 iOS 26 SDK）：用原生 Liquid Glass `glassEffect`
    /// - 老 Xcode（如 macos-14 镜像的 Xcode 16）：自动走毛玻璃，保证工程照样能编译
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        } else {
            fallbackGlass(shape)
        }
        #else
        fallbackGlass(shape)
        #endif
    }

    @ViewBuilder
    private func fallbackGlass<S: InsettableShape>(_ shape: S) -> some View {
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
