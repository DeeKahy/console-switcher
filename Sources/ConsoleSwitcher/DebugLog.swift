import Foundation

/// Plain-file logging, deliberately not NSLog/os_log: the unified logging
/// system redacts string-interpolated NSLog messages to "<private>" by
/// default on this machine, which made every diagnostic message invisible
/// while debugging the controller trigger. This writes straight to disk
/// instead, with no redaction to fight.
private let logPath = "/tmp/consoleswitcher_debug.log"
private let logQueue = DispatchQueue(label: "consoleswitcher.debuglog")

func debugLog(_ message: String) {
    logQueue.async {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}
