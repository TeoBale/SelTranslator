import Foundation
import OSLog

/// Content-free, allowlisted milestones. Never pass framework errors or user text here.
@MainActor
final class Diagnostics {
    static let shared = Diagnostics()
    private let logger = Logger(subsystem: "com.selectiontranslator.app", category: "latency")
    private var starts: [UUID: ContinuousClock.Instant] = [:]
    private var count = 0
    private var inputLength = 0
    private let allowedStages: Set<String> = ["shortcut_received", "acknowledgement_submitted", "selection_captured", "input_ready", "source_detected", "availability_checked", "session_prepared", "translation_completed", "result_ready", "result_presented", "replacement_completed", "retry_started", "superseded", "cancelled", "missing_models", "empty_input", "uncertain_source", "unsupported_pair", "failed"]
    func begin(_ id: UUID) {
        starts = [id: .now]
        count += 1
        inputLength = 0
        mark(id, "shortcut_received")
    }
    func mark(_ id: UUID, _ event: String, length: Int? = nil) {
        guard allowedStages.contains(event), let start = starts[id] else { return }
        if let length { inputLength = length }
        let elapsed = start.duration(to: .now)
        let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        logger.info("request=\(id.uuidString, privacy: .public) stage=\(event, privacy: .public) elapsed_ms=\(ms, privacy: .public) length=\(self.inputLength, privacy: .public) app_cold=\(self.count == 1, privacy: .public)")
    }
}
