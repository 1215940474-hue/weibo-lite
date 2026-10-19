import Combine
import SwiftUI

/// 全屏媒体统一在根视图呈现，避免把 fullScreenCover 挂在列表 cell 里（cell 被回收时容易闪退）。
@MainActor
final class MediaPresenter: ObservableObject {
    @Published var imagePayload: ImageViewerPayload?
    @Published var videoURL: URLIdentifiable?

    func openImage(_ payload: ImageViewerPayload) {
        imagePayload = payload
    }

    func openVideo(_ url: URL) {
        videoURL = URLIdentifiable(url: url)
    }
}

struct URLIdentifiable: Identifiable {
    let id = UUID()
    let url: URL
}
