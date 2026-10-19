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
    /// iOS 26 原生液态玻璃；低版本自动退回材质毛玻璃。
    /// 工程用 Xcode 26 构建，所以 `#available` 判断一定有新 SDK 可用。
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        self.glassSurface(Capsule(style: .continuous))
    }
}

/// 统一的信息卡片外观（原生液态玻璃）
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
