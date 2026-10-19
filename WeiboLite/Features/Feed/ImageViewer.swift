import Photos
import SwiftUI
import UIKit

/// 图片查看器入参（用于 fullScreenCover(item:)）
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

/// 全屏看图：淡入缩放出现（不上下跳）、左右翻页、单击退出、双击/双指缩放、长按弹保存确认。
struct ImageViewer: View {
    let payload: ImageViewerPayload
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var appeared = false
    @State private var toast: String?

    init(payload: ImageViewerPayload) {
        self.payload = payload
        _index = State(initialValue: payload.startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(payload.urls.enumerated()), id: \.offset) { item in
                    ViewerPage(
                        url: item.element,
                        onDismiss: { dismiss() },
                        onSaveResult: { success in
                            showToast(success ? "已保存到相册" : "保存失败，请检查相册权限")
                        }
                    )
                    .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            topBar
        }
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { appeared = true }
        }
        .overlay(alignment: .bottom) {
            if let toast = toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .padding(.bottom, 50)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text(payload.urls.count > 1 ? "\(index + 1)/\(payload.urls.count)" : "1/1")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.18), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { toast = nil }
        }
    }
}

/// 单页大图：加载原图、双指缩放、双击放大、单击退出、长按弹保存/取消。
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
                            withAnimation(.easeInOut(duration: 0.2)) {
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

/// 自带大图查看能力的图片九宫格（由根视图统一呈现查看器）。
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
