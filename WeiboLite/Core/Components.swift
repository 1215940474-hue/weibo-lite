import Foundation
import SwiftUI

struct AvatarView: View {
    let url: URL?
    let size: CGFloat
    var fallbackText: String? = nil

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }

    @ViewBuilder
    private var fallback: some View {
        if let fallbackText = fallbackText, !fallbackText.isEmpty {
            ZStack {
                Color.accentColor.opacity(0.16)
                Text(fallbackText)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        } else {
            Color(uiColor: .tertiarySystemFill)
        }
    }
}

struct CountLabel: View {
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            if count > 0 {
                Text(formatted)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var formatted: String {
        if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return String(count)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 顶部渐进模糊：滚动内容进入导航栏下方时逐渐虚化。
struct TopBlurFade: View {
    var height: CGFloat = 24

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: height)
            .mask(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.55), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }
}
