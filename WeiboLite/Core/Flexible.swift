import Foundation

/// 微博接口里同一个字段可能是 String / Int / Double，这里统一兜底，避免整条数据解码失败。
struct FlexID: Decodable, Hashable {
    let value: String

    init(_ value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self), !string.isEmpty {
            value = string
        } else if let int = try? container.decode(Int64.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(Int64(double))
        } else {
            value = ""
        }
    }
}

/// 同上，用于评论数、点赞数这类可能以字符串返回的数字。
struct FlexInt: Decodable, Hashable {
    let value: Int

    init(_ value: Int) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = Int(string) ?? 0
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else {
            value = 0
        }
    }
}

/// 只用来判断某个 key「存在且非 null」，不关心内容。
struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {}
}

extension KeyedDecodingContainer {
    /// 宽容解码：字段缺失、类型不符都返回 nil，不会让整条微博解码失败。
    func soft<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
