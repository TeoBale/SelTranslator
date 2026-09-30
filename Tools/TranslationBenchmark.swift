import Foundation
import Translation

@main
struct TranslationBenchmark {
    struct Sample: Codable {
        let pair: String
        let ownership: String
        let workload: String
        let iteration: Int
        let appCold: Bool
        let availabilityMilliseconds: Double
        let preparationMilliseconds: Double
        let translationMilliseconds: Double
        let totalMilliseconds: Double
        let outcome: String
        let textLength: Int
    }
    struct PairStatus: Codable { let pair: String; let status: String; let milliseconds: Double }
    struct Report: Codable { let statuses: [PairStatus]; let samples: [Sample] }
    static func elapsed(_ start: ContinuousClock.Instant) -> Double {
        let value = start.duration(to: .now).components
        return Double(value.seconds) * 1_000 + Double(value.attoseconds) / 1e15
    }
    static func main() async { await run() }
    nonisolated static func run() async {
        var statuses: [PairStatus] = []
        var samples: [Sample] = []
        let short = "The train leaves tomorrow morning."
        let paragraph = "The train leaves tomorrow morning. Please arrive at the station early and bring your ticket. We will meet near the main entrance, then walk together to the platform. If the schedule changes, contact the information desk before boarding."
        let availability = LanguageAvailability()
        for target in ["it", "fr", "de"] {
            let from = Locale.Language(identifier: "en")
            let to = Locale.Language(identifier: target)
            let pair = "en-\(target)"
            let check = ContinuousClock.now
            let status = await availability.status(from: from, to: to)
            let checkTime = elapsed(check)
            let label: String
            switch status {
            case .installed: label = "installed"
            case .supported: label = "missing_models"
            case .unsupported: label = "unsupported"
            @unknown default: label = "unknown"
            }
            statuses.append(PairStatus(pair: pair, status: label, milliseconds: checkTime))
            guard status == .installed else {
                for iteration in 0..<10 {
                    let start = ContinuousClock.now
                    let current = await availability.status(from: from, to: to)
                    let label: String
                    switch current {
                    case .installed: label = "installed"
                    case .supported: label = "missing_models"
                    case .unsupported: label = "unsupported"
                    @unknown default: label = "unknown"
                    }
                    samples.append(Sample(pair: pair, ownership: "availability_only", workload: "pair_switch", iteration: iteration, appCold: false, availabilityMilliseconds: elapsed(start), preparationMilliseconds: 0, translationMilliseconds: 0, totalMilliseconds: elapsed(start), outcome: label, textLength: 0))
                }
                continue
            }
            for ownership in ["fresh", "retained"] {
                // A session never leaves this task. No actor transfer or shared global owner.
                var retained: TranslationSession?
                for (workload, text) in [("short", short), ("paragraph", paragraph)] {
                    for iteration in 0..<10 {
                        let start = ContinuousClock.now
                        let checkStart = ContinuousClock.now
                        let current = await availability.status(from: from, to: to)
                        let availabilityTime = elapsed(checkStart)
                        guard current == .installed else {
                            samples.append(Sample(pair: pair, ownership: ownership, workload: workload, iteration: iteration, appCold: samples.isEmpty, availabilityMilliseconds: availabilityTime, preparationMilliseconds: 0, translationMilliseconds: 0, totalMilliseconds: elapsed(start), outcome: "missing_models", textLength: text.utf16.count))
                            retained = nil
                            break
                        }
                        let session = retained ?? TranslationSession(installedSource: from, target: to)
                        var preparationTime = 0.0
                        var translationTime = 0.0
                        var outcome = "success"
                        do {
                            let preparationStart = ContinuousClock.now
                            try await session.prepareTranslation()
                            preparationTime = elapsed(preparationStart)
                            let translationStart = ContinuousClock.now
                            _ = try await session.translate(text)
                            translationTime = elapsed(translationStart)
                            if ownership == "retained" { retained = session }
                        } catch {
                            retained = nil
                            switch error {
                            case TranslationError.notInstalled: outcome = "missing_models"
                            case TranslationError.alreadyCancelled: outcome = "cancelled"
                            default: outcome = "translation_failure"
                            }
                        }
                        samples.append(Sample(pair: pair, ownership: ownership, workload: workload, iteration: iteration, appCold: samples.isEmpty, availabilityMilliseconds: availabilityTime, preparationMilliseconds: preparationTime, translationMilliseconds: translationTime, totalMilliseconds: elapsed(start), outcome: outcome, textLength: text.utf16.count))
                        if outcome != "success" { break }
                    }
                }
            }
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Report(statuses: statuses, samples: samples))
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch { exit(1) }
    }
}
