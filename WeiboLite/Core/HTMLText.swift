import Foundation

/// 把微博返回的 HTML 正文转成可显示的纯文本：
/// 去标签、保留 <br> 换行、把表情 <img alt="[微笑]"> 还原成文字。
enum HTMLText {
    static func plain(_ html: String?) -> String {
        guard var text = html, !text.isEmpty else { return "" }

        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<img[^>]*alt=\"([^\"]*)\"[^>]*>", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&#x27;", "'"),
            ("&apos;", "'"),
            ("&amp;", "&")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = decodeNumericEntities(text)

        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeNumericEntities(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);", options: []) else {
            return input
        }
        let ns = input as NSString
        var output = ""
        var cursor = 0
        for match in regex.matches(in: input, options: [], range: NSRange(location: 0, length: ns.length)) {
            output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let isHex = ns.substring(with: match.range(at: 1)) == "x"
            let digits = ns.substring(with: match.range(at: 2))
            let code = isHex ? UInt32(digits, radix: 16) : UInt32(digits, radix: 10)
            if let code = code, let scalar = UnicodeScalar(code) {
                output.append(Character(scalar))
            }
            cursor = match.range.location + match.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }
}
