import Combine
import SwiftUI

/// 全屏媒体统一在根视图呈现，避免把 fullScreenCover 挂在列表 cell 里（cell 被回收时容易闪退）。
final class MediaPresenter: ObservableObject {
    @Published var imagePayload: ImageViewerPayload?
    @Published var videoURL: URLIdentifiable?

    func openImage(_ payload: ImageViewerPayload) {
        CrashTrace.log("openImage count=\(payload.urls.count) index=\(payload.startIndex)")
        imagePayload = payload
    }

    func openVideo(_ url: URL) {
        CrashTrace.log("openVideo \(url.absoluteString.prefix(120))")
        videoURL = URLIdentifiable(url: url)
    }
}

struct URLIdentifiable: Identifiable {
    let id = UUID()
    let url: URL
}

/// 用 Environment 自定义 key 替代 EnvironmentObject：即使某个层级没注入，也不会因为
/// "No ObservableObject of type MediaPresenter found" 直接 fatalError。
private struct MediaPresenterKey: EnvironmentKey {
    static let defaultValue = MediaPresenter()
}

extension EnvironmentValues {
    var mediaPresenter: MediaPresenter {
        get { self[MediaPresenterKey.self] }
        set { self[MediaPresenterKey.self] = newValue }
    }
}
