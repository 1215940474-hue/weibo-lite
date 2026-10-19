import SwiftUI
import UIKit

/// 带内存缓存的图片加载器：大图、视频封面、单图自适应比例都用它。
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session = URLSession(configuration: .default)

    private init() {
        cache.countLimit = 120
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let image = cached(url) {
            completion(image)
            return
        }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.cache.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    /// 表情图：加载并缩放到和正文文字等高
    func loadEmoji(_ url: URL, pointHeight: CGFloat = 19, completion: @escaping (UIImage?) -> Void) {
        load(url) { image in
            guard let image = image else {
                completion(nil)
                return
            }
            let scale = UIScreen.main.scale
            let target = CGSize(width: pointHeight * scale, height: pointHeight * scale)
            let renderer = UIGraphicsImageRenderer(size: target)
            let resized = renderer.image { _ in
                let ratio = min(target.width / image.size.width, target.height / image.size.height)
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                image.draw(in: CGRect(
                    x: (target.width - size.width) / 2,
                    y: (target.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                ))
            }
            completion(resized)
        }
    }
}

/// 固定填充方式的远程图片（九宫格用）。
struct RemoteImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color(uiColor: .tertiarySystemFill)
                    .overlay {
                        ProgressView().controlSize(.small)
                    }
            }
        }
        .task(id: url) {
            guard let url = url else {
                image = nil
                return
            }
            ImageLoader.shared.load(url) { loaded in
                image = loaded
            }
        }
    }
}

/// 按图片真实长宽比显示（单图预览用，不再强制 4:3 / 正方形）。
struct AdaptiveRemoteImage: View {
    let url: URL
    var maxHeight: CGFloat = 460
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
                    .frame(maxHeight: maxHeight)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            ImageLoader.shared.load(url) { loaded in
                image = loaded
            }
        }
    }
}
