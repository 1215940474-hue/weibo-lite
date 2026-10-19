import Foundation

/// 把微博返回的各种时间字符串统一成中文显示。
///
/// 微博不同接口的 `created_at` 格式不统一，常见有：
/// - 相对时间：「刚刚 / 5分钟前 / 3小时前 / 今天 12:30 / 昨天 12:30」
/// - 英文格式：「Sat Jul 19 12:00:00 +0800 2025」（用户看到的英文日期就是这种）
/// - 短格式：「07-19」「2025-07-19」「2025-07-19 12:00」
enum ChineseDate {
    private static let englishFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    private static let numericFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "MM-dd HH:mm",
        "MM-dd"
    ]

    private static let relativeWords = ["刚刚", "分钟前", "小时前", "今天", "昨天", "前天"]

    static func display(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        // 已经是中文相对时间，直接展示
        if relativeWords.contains(where: { text.contains($0) }) {
            return text
        }

        if let date = parse(text) {
            return format(date)
        }
        return text
    }

    // MARK: - 解析

    private static func parse(_ text: String) -> Date? {
        if let date = englishFormatter.date(from: text) {
            return date
        }
        if let date = isoFormatter.date(from: text) {
            return date
        }
        for format in numericFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateFormat = format
            guard let date = formatter.date(from: text) else { continue }
            // 「07-19」这类没有年份，默认补当前年；如果落在未来就减一年
            if format.hasPrefix("MM-dd") {
                let calendar = Calendar.current
                let now = Date()
                var components = calendar.dateComponents([.year], from: now)
                let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
                components.month = parts.month
                components.day = parts.day
                components.hour = parts.hour ?? 0
                components.minute = parts.minute ?? 0
                var corrected = calendar.date(from: components) ?? date
                if corrected > now.addingTimeInterval(60) {
                    components.year = (components.year ?? 2025) - 1
                    corrected = calendar.date(from: components) ?? corrected
                }
                return corrected
            }
            return date
        }
        return nil
    }

    // MARK: - 输出

    private static func format(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 {
            return "刚刚"
        }
        if seconds < 3600 {
            return "\(max(1, Int(seconds / 60)))分钟前"
        }
        if calendar.isDateInToday(date) {
            return "今天 " + timeString(date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 " + timeString(date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "M月d日" : "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
