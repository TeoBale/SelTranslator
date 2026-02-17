import Foundation
import os

enum Diagnostics {
    private static let logger = Logger(
        subsystem: "com.teobale.seltranslator",
        category: "runtime"
    )

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        fputs("[SelTranslator] \(message)\n", stderr)
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        fputs("[SelTranslator] ERROR: \(message)\n", stderr)
    }

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        var parts: [String] = [
            "type=\(String(reflecting: type(of: error)))",
            "description=\(error.localizedDescription)",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)"
        ]
        if !nsError.userInfo.isEmpty {
            parts.append("userInfo=\(nsError.userInfo)")
        }
        return parts.joined(separator: " | ")
    }
}
