import SwiftUI
import UIKit

/// 图片查看器入参（用于 fullScreenCover(item:)）
struct ImageViewerPayload: Identifiable {
    let id = UUID()
    let urls: [URL]
    let startIndex: Int
}

enum WeiboImage {
    /// 把缩略图地址换成原图地址（/large/、/mw690/ 等 → /original/）
    static func original(_ url: URL) -> URL {
        var string = url.absoluteString
        let tokens = ["/large/", "/mw690/", "/bmiddle/", "/thumbnail/", "/thumb150/", "/square/", "/orj360/"]
        for token in tokens where string.contains(token) {
            string = string.replacingOccurrences(of: token, with: "/original/")
            return URL(string: string) ?? url
        }
        return url
    }
}

/// 点开图片看大图：左右翻页、双指/双击缩放、单击退出、长按保存到相册。
struct ImageViewer: View {
    let payload: ImageViewerPayload
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var toast: String?

    init(payload: ImageViewerPayload) {
        self.payload = payload
        _index = State(initialValue: payload.startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(payload.urls.enumerated()), id: \.offset) { item in
                    ZoomableImage(
                        url: item.element,
                        onSingleTap: { dismiss() },
                        onSaveResult: { success in
                            showToast(success ? "已保存到相册" : "保存失败，请检查相册权限")
                        }
                    )
                    .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Text("\(index + 1)/\(payload.urls.count)")
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

            if let toast = toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 60)
                    .transition(.opacity)
            }
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

/// 单张可缩放大图
private struct ZoomableImage: UIViewRepresentable {
    let url: URL
    let onSingleTap: () -> Void
    let onSaveResult: (Bool) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.attach(scrollView: scrollView, imageView: imageView, url: url)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onSaveResult: onSaveResult)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        private let onSingleTap: () -> Void
        private let onSaveResult: (Bool) -> Void
        private weak var scrollView: UIScrollView?
        private weak var imageView: UIImageView?

        init(onSingleTap: @escaping () -> Void, onSaveResult: @escaping (Bool) -> Void) {
            self.onSingleTap = onSingleTap
            self.onSaveResult = onSaveResult
        }

        func attach(scrollView: UIScrollView, imageView: UIImageView, url: URL) {
            self.scrollView = scrollView
            self.imageView = imageView

            let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            singleTap.require(toFail: doubleTap)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.6

            scrollView.addGestureRecognizer(singleTap)
            scrollView.addGestureRecognizer(doubleTap)
            scrollView.addGestureRecognizer(longPress)

            loadImage(url: url, into: imageView)
        }

        private func loadImage(url: URL, into imageView: UIImageView) {
            let original = WeiboImage.original(url)
            ImageLoader.shared.load(original) { [weak self] image in
                if let image = image {
                    imageView.image = image
                } else {
                    // 原图拿不到就退回缩略图
                    ImageLoader.shared.load(url) { [weak self] fallback in
                        guard let fallback = fallback else {
                            self?.onSaveResult(false)
                            return
                        }
                        imageView.image = fallback
                    }
                }
            }
        }

        @objc private func handleSingleTap() {
            onSingleTap()
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let zoomScale: CGFloat = 2.5
                let width = scrollView.bounds.width / zoomScale
                let height = scrollView.bounds.height / zoomScale
                let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
                scrollView.zoom(to: rect, animated: true)
            }
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let image = imageView?.image else { return }
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }

        @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
            onSaveResult(error == nil)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}

/// 自带大图查看能力的图片九宫格，卡片里直接用它。
struct TappableImageGrid: View {
    let pics: [WBPic]
    @State private var viewer: ImageViewerPayload?

    var body: some View {
        ImageGrid(pics: pics) { index in
            let urls = pics.compactMap { $0.url }
            guard !urls.isEmpty else { return }
            viewer = ImageViewerPayload(urls: urls, startIndex: min(index, urls.count - 1))
        }
        .fullScreenCover(item: $viewer) { payload in
            ImageViewer(payload: payload)
        }
    }
}
