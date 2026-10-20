import Photos
import SwiftUI
import UIKit

/// 图片查看器入参
struct ImageViewerPayload: Identifiable {
    let id = UUID()
    let urls: [URL]
    let startIndex: Int
}

enum WeiboImage {
    private static let tokens = ["/large/", "/mw690/", "/bmiddle/", "/thumbnail/", "/thumb150/", "/square/", "/orj360/", "/original/"]

    static func original(_ url: URL) -> URL { replaced(url, with: "/original/") }
    static func large(_ url: URL) -> URL { replaced(url, with: "/large/") }
    static func thumbnail(_ url: URL) -> URL { replaced(url, with: "/mw690/") }

    private static func replaced(_ url: URL, with target: String) -> URL {
        var string = url.absoluteString
        for token in tokens where string.contains(token) {
            string = string.replacingOccurrences(of: token, with: target)
            return URL(string: string) ?? url
        }
        return url
    }
}

/// 全屏看图：
/// - 出现：缩放 + 淡入（spring，不生硬）
/// - 按住下滑：图片跟手缩小、渐隐，背景同步透明，松手过阈值关闭
/// - 单击关闭、双击缩放、双指缩放、长按保存（确认框）
struct ImageViewer: View {
    let payload: ImageViewerPayload
    var onClose: () -> Void = {}

    @State private var index: Int
    @State private var appeared = false
    @State private var dragTranslation: CGSize = .zero
    @State private var toast: String?

    init(payload: ImageViewerPayload, onClose: @escaping () -> Void = {}) {
        self.payload = payload
        self.onClose = onClose
        _index = State(initialValue: payload.startIndex)
    }

    /// 0...1 拖拽进度：控制缩放/透明度/背景
    private var dragProgress: CGFloat {
        min(max(dragTranslation.height / 420, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .opacity(appeared ? Double(1 - dragProgress * 0.9) : 0)
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(payload.urls.enumerated()), id: \.offset) { item in
                    ViewerPage(
                        url: item.element,
                        onDismiss: dismissViewer,
                        onSaveResult: { success in
                            showToast(success ? "已保存到相册" : "保存失败，请检查相册权限")
                        }
                    )
                    .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragTranslation.height)
            .scaleEffect(1 - dragProgress * 0.22)
            .opacity(appeared ? Double(1 - dragProgress * 0.55) : 0)

            counter
        }
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .simultaneousGesture(dragGesture)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                appeared = true
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .padding(.bottom, 80)
            }
        }
    }

    private var counter: some View {
        Text(payload.urls.count > 1 ? "\(index + 1)/\(payload.urls.count)" : "1/1")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.35), in: Capsule())
            .padding(.top, 10)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragTranslation = CGSize(width: 0, height: max(0, value.translation.height))
            }
            .onEnded { value in
                let farEnough = value.translation.height > 160
                let fastEnough = value.predictedEndTranslation.height > 420
                if farEnough || fastEnough {
                    dismissViewer()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        dragTranslation = .zero
                    }
                }
            }
    }

    private func dismissViewer() {
        withAnimation(.easeOut(duration: 0.22)) {
            appeared = false
            dragTranslation = CGSize(width: 0, height: 400)
        }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            onClose()
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { toast = nil }
        }
    }
}

/// 单页大图
private struct ViewerPage: View {
    let url: URL
    let onDismiss: () -> Void
    let onSaveResult: (Bool) -> Void

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var showSaveDialog = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .gesture(magnification)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = scale > 1 ? 1 : 2.5
                                lastScale = scale
                            }
                        }
                        .onTapGesture {
                            onDismiss()
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showSaveDialog = true
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: url) {
            let original = WeiboImage.original(url)
            ImageLoader.shared.load(original) { loaded in
                if let loaded = loaded {
                    image = loaded
                } else {
                    ImageLoader.shared.load(url) { fallback in
                        image = fallback
                    }
                }
            }
        }
        .confirmationDialog("图片", isPresented: $showSaveDialog, titleVisibility: .visible) {
            Button("保存到相册") { save() }
            Button("取消", role: .cancel) {}
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func save() {
        guard let image = image else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { onSaveResult(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                DispatchQueue.main.async { onSaveResult(success) }
            }
        }
    }
}

/// 自带大图查看能力的图片九宫格
struct TappableImageGrid: View {
    let pics: [WBPic]
    @Environment(\.mediaPresenter) private var media: MediaPresenter

    var body: some View {
        ImageGrid(pics: pics) { index in
            let urls = pics.compactMap { $0.url }
            guard !urls.isEmpty else { return }
            media.openImage(
                ImageViewerPayload(urls: urls, startIndex: min(index, urls.count - 1))
            )
        }
    }
}
