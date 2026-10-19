import SwiftUI
import UIKit

/// 图片查看器入参（用于 fullScreenCover(item:)）
struct ImageViewerPayload: Identifiable {
    let id = UUID()
    let urls: [URL]
    let startIndex: Int
}

/// 点开图片查看大图：左右翻页 + 双指缩放
struct ImageViewer: View {
    let payload: ImageViewerPayload
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(payload: ImageViewerPayload) {
        self.payload = payload
        _index = State(initialValue: payload.startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(payload.urls.enumerated()), id: \.offset) { item in
                    ZoomableImage(url: item.element)
                        .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

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
    }
}

/// 支持双指缩放 + 双击放大的单张图片
private struct ZoomableImage: UIViewRepresentable {
    let url: URL

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

        context.coordinator.imageView = imageView
        context.coordinator.load(url: url)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private var task: URLSessionDataTask?

        func load(url: URL) {
            task?.cancel()
            task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.imageView?.image = image
                }
            }
            task?.resume()
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
