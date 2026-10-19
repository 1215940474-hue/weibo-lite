import SwiftUI
import UIKit

/// 可点击的正文：自动识别 http/https 链接，点击用系统浏览器（Safari）打开。
struct LinkableText: View {
    let text: String
    var font: Font = .system(size: 16)
    var lineSpacing: CGFloat = 4
    var lineLimit: Int? = nil

    var body: some View {
        Text(attributed)
            .font(font)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
            .tint(.blue)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                UIApplication.shared.open(url)
                return .handled
            })
    }

    private var attributed: AttributedString {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return AttributedString(text)
        }

        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
        guard !matches.isEmpty else { return AttributedString(text) }

        var result = AttributedString()
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                result += AttributedString(String(text[cursor..<range.lowerBound]))
            }
            var linked = AttributedString(String(text[range]))
            if let url = match.url {
                linked.link = url
            }
            result += linked
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            result += AttributedString(String(text[cursor...]))
        }
        return result
    }
}
