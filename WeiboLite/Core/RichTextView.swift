import SwiftUI
import UIKit

enum RichSegment: Hashable {
    case text(String)
    case emoji(alt: String, url: URL?)
    case link(label: String, url: URL?)
}

/// 解析微博 HTML：
/// - `<img class="emoji">` → 官方表情图
/// - `<a href>` → 显示锚文本（官方就是「网页链接」「#话题#」「@用户」），不再显示裸 URL
enum RichHTML {
    private static let imgRegex = try? NSRegularExpression(pattern: "<img[^>]*>", options: [.caseInsensitive])
    private static let altRegex = try? NSRegularExpression(pattern: "alt=\"([^\"]*)\"", options: [.caseInsensitive])
    private static let srcRegex = try? NSRegularExpression(pattern: "src=\"([^\"]*)\"", options: [.caseInsensitive])
    private static let anchorRegex = try? NSRegularExpression(
        pattern: "<a[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>",
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let placeholderRegex = try? NSRegularExpression(pattern: "\u{1}(\\d+)\u{1}")

    static func segments(from html: String) -> [RichSegment] {
        var working = html
        var links: [(label: String, url: URL?)] = []

        // 1) 把 <a> 换成占位符，避免链接文字被当普通文本
        if let regex = anchorRegex {
            let ns = working as NSString
            let matches = regex.matches(in: working, options: [], range: NSRange(location: 0, length: ns.length))
            let result = NSMutableString(string: working)
            for (index, match) in matches.enumerated().reversed() where match.numberOfRanges > 2 {
                let href = ns.substring(with: match.range(at: 1))
                let inner = ns.substring(with: match.range(at: 2))
                links.insert((label: linkLabel(inner: inner), url: normalURL(href)), at: index)
                result.replaceCharacters(in: match.range, with: "\u{1}\(index)\u{1}")
            }
            working = result as String
        }

        // 2) 按 <img> 切分，图片之间/前后的文字再按占位符切出链接
        var segments: [RichSegment] = []
        let ns = working as NSString
        let imgMatches = imgRegex?.matches(in: working, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        var cursor = 0

        for match in imgMatches {
            if match.range.location > cursor {
                let before = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                appendChunk(&segments, before, links: links)
            }
            let tag = ns.substring(with: match.range)
            let alt = firstGroup(in: tag, regex: altRegex)
            let src = firstGroup(in: tag, regex: srcRegex)
            if !alt.isEmpty || !src.isEmpty {
                segments.append(.emoji(alt: alt.isEmpty ? "[表情]" : alt, url: normalURL(src)))
            }
            cursor = match.range.location + match.range.length
        }

        if cursor < ns.length {
            appendChunk(&segments, ns.substring(from: cursor), links: links)
        }
        return segments
    }

    private static func appendChunk(
        _ segments: inout [RichSegment],
        _ raw: String,
        links: [(label: String, url: URL?)]
    ) {
        let ns = raw as NSString
        let matches = placeholderRegex?.matches(in: raw, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        var last = 0

        for match in matches {
            if match.range.location > last {
                let before = ns.substring(with: NSRange(location: last, length: match.range.location - last))
                appendText(&segments, before)
            }
            guard match.numberOfRanges > 1 else { continue }
            if let index = Int(ns.substring(with: match.range(at: 1))), index >= 0, index < links.count {
                segments.append(.link(label: links[index].label, url: links[index].url))
            }
            last = match.range.location + match.range.length
        }

        if last < ns.length {
            appendText(&segments, ns.substring(from: last))
        }
    }

    private static func appendText(_ segments: inout [RichSegment], _ raw: String) {
        let cleaned = HTMLText.plain(raw)
        guard !cleaned.isEmpty else { return }
        if case .text(let previous)? = segments.last {
            segments[segments.count - 1] = .text(previous + cleaned)
        } else {
            segments.append(.text(cleaned))
        }
    }

    /// 官方样式：网页外链统一显示「网页链接」；话题 #xxx#、@用户 原样保留
    private static func linkLabel(inner: String) -> String {
        let label = HTMLText.plain(inner).trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty { return "网页链接" }
        if label.hasPrefix("#") || label.hasPrefix("@") { return label }
        if label.contains("网页链接") || label.contains("全文") { return "网页链接" }
        if label.count > 14 || label.lowercased().hasPrefix("http") { return "网页链接" }
        return label
    }

    private static func normalURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("//") { return URL(string: "https:" + value) }
        if value.hasPrefix("http") { return URL(string: value) }
        return nil
    }

    private static func firstGroup(in text: String, regex: NSRegularExpression?) -> String {
        guard let regex = regex else { return "" }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return "" }
        return ns.substring(with: match.range(at: 1))
    }
}

/// 渲染正文：文字 + 官方表情图 + 蓝色链接。
/// - `interactiveLinks`: 卡片里包着 NavigationLink 时设为 false，避免抢走卡片点击
struct RichTextView: View {
    let html: String
    var font: Font = .system(size: 16)
    /// 字号（用于计算表情图高度，让表情和文字一样大）
    var fontSize: CGFloat = 16
    var lineSpacing: CGFloat = 4
    var lineLimit: Int? = nil
    var interactiveLinks: Bool = true

    @State private var segments: [RichSegment] = []
    @State private var emojiImages: [Int: UIImage] = [:]

    var body: some View {
        textContent
            .font(font)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                UIApplication.shared.open(url)
                return .handled
            })
            .task(id: html) {
                build()
            }
    }

    private var textContent: Text {
        var result = Text("")
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .text(let string):
                result = result + Text(string)
            case .emoji(let alt, _):
                if let image = emojiImages[index] {
                    result = result + Text(Image(uiImage: image))
                } else {
                    result = result + Text(alt)
                }
            case .link(let label, let url):
                var part = AttributedString(label)
                part.foregroundColor = .blue
                if interactiveLinks, let url = url {
                    part.link = url
                }
                result = result + Text(part)
            }
        }
        return result
    }

    private func build() {
        let parsed = RichHTML.segments(from: html)
        CrashTrace.log("richtext build html=\(html.count) chars segments=\(parsed.count)")
        segments = parsed
        // 表情图的点高度 = 字号，保证和正文一样大
        let emojiHeight = max(14, fontSize * 1.0)
        for (index, segment) in parsed.enumerated() {
            guard case .emoji(_, let url) = segment, let url = url else { continue }
            ImageLoader.shared.loadEmoji(url, pointHeight: emojiHeight) { image in
                guard let image = image else { return }
                emojiImages[index] = image
            }
        }
    }
}
