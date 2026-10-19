import SwiftUI
import UIKit

enum RichSegment: Hashable {
    case text(String)
    case emoji(alt: String, url: URL?)
}

/// 把微博的 HTML 正文拆成「文字 / 官方表情图」两种片段。
/// 同时把 <a href="..."> 的锚文本替换成真实 URL，保证链接可见、可点、可标蓝。
enum RichHTML {
    private static let imgRegex = try? NSRegularExpression(pattern: "<img[^>]*>", options: [.caseInsensitive])
    private static let altRegex = try? NSRegularExpression(pattern: "alt=\"([^\"]*)\"", options: [.caseInsensitive])
    private static let srcRegex = try? NSRegularExpression(pattern: "src=\"([^\"]*)\"", options: [.caseInsensitive])
    private static let anchorRegex = try? NSRegularExpression(
        pattern: "<a[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>",
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    static func segments(from html: String) -> [RichSegment] {
        var text = replaceAnchors(html)
        var segments: [RichSegment] = []
        let ns = text as NSString
        let matches = imgRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let before = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                appendText(&segments, before)
            }
            let tag = ns.substring(with: match.range)
            let alt = firstGroup(in: tag, regex: altRegex)
            let src = firstGroup(in: tag, regex: srcRegex)
            let url = normalizedURL(src)
            if !alt.isEmpty || url != nil {
                segments.append(.emoji(alt: alt.isEmpty ? "[表情]" : alt, url: url))
            }
            cursor = match.range.location + match.range.length
        }

        if cursor < ns.length {
            appendText(&segments, ns.substring(from: cursor))
        }
        return segments
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

    private static func replaceAnchors(_ html: String) -> String {
        guard let regex = anchorRegex else { return html }
        let ns = html as NSString
        let result = NSMutableString(string: html)
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() where match.numberOfRanges > 1 {
            let href = ns.substring(with: match.range(at: 1))
            result.replaceCharacters(in: match.range, with: href)
        }
        return result as String
    }

    private static func firstGroup(in text: String, regex: NSRegularExpression?) -> String {
        guard let regex = regex else { return "" }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return "" }
        return ns.substring(with: match.range(at: 1))
    }

    private static func normalizedURL(_ src: String) -> URL? {
        guard !src.isEmpty else { return nil }
        if src.hasPrefix("//") {
            return URL(string: "https:" + src)
        }
        return URL(string: src)
    }
}

/// 渲染正文：文字 + 官方表情图 + 蓝色可点链接。
struct RichTextView: View {
    let html: String
    var font: Font = .system(size: 16)
    var lineSpacing: CGFloat = 4
    var lineLimit: Int? = nil

    @State private var segments: [RichSegment] = []
    @State private var emojiImages: [Int: UIImage] = [:]

    var body: some View {
        textContent
            .font(font)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
            .tint(.blue)
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
                result = result + Text(linked(string))
            case .emoji(let alt, _):
                if let image = emojiImages[index] {
                    result = result + Text(Image(uiImage: image))
                } else {
                    result = result + Text(alt)
                }
            }
        }
        return result
    }

    private func build() {
        let parsed = RichHTML.segments(from: html)
        segments = parsed
        for (index, segment) in parsed.enumerated() {
            guard case .emoji(_, let url) = segment, let url = url else { continue }
            ImageLoader.shared.loadEmoji(url) { image in
                guard let image = image else { return }
                emojiImages[index] = image
            }
        }
    }

    /// 把纯文本里的 URL 标成蓝色可点
    private func linked(_ string: String) -> AttributedString {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return AttributedString(string)
        }
        let ns = string as NSString
        let matches = detector.matches(in: string, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return AttributedString(string) }

        var result = AttributedString()
        var cursor = string.startIndex
        for match in matches {
            guard let range = Range(match.range, in: string) else { continue }
            if cursor < range.lowerBound {
                result += AttributedString(String(string[cursor..<range.lowerBound]))
            }
            var part = AttributedString(String(string[range]))
            if let url = match.url {
                part.link = url
            }
            part.foregroundColor = Color.blue
            result += part
            cursor = range.upperBound
        }
        if cursor < string.endIndex {
            result += AttributedString(String(string[cursor...]))
        }
        return result
    }
}
