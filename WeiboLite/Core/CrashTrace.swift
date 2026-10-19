import Foundation

/// 极简本地日志（面包屑）：闪退前最后几步会落盘，配合崩溃日志定位问题。
/// 文件位于 App 沙盒 Documents/weibolite.log，可通过「文件」App 或「我 → 导出诊断日志」取走。
enum CrashTrace {
    private static let lock = NSLock()

    static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("weibolite.log")
    }

    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let url = fileURL else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
