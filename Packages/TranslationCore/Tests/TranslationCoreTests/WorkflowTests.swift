import Foundation
import Testing
@testable import TranslationCore

@MainActor private final class Selection: SelectionAccess {
    var captureFailure = false
    var text = "  hello \n"; var writable = true; var failure = false; var replacements: [String] = []
    func capture(requestID: UUID) async throws -> SelectionSnapshot { if captureFailure { throw TranslationIssue.failed }; return .init(requestID: requestID, text: text, applicationBundleID: "test", processID: 42, range: .init(location: 1, length: text.utf16.count), isEditable: writable) }
    func replace(snapshot: SelectionSnapshot, with text: String, requestID: UUID, isCurrent: @escaping @MainActor () -> Bool) async throws { guard isCurrent(), !failure, writable else { throw TranslationIssue.failed }; replacements.append(text) }
}
@MainActor private final class Engine: TranslationEngine {
    var cancellations = 0
    func cancelActive() { cancellations += 1 }
    var calls = 0; var output = TranslationOutput(text: "bonjour", source: "en", target: "fr"); var issue: TranslationIssue?
    var pending: [CheckedContinuation<TranslationOutput, any Error>] = []; var suspend = false
    func translate(text: String, source: String?, target: String, requestID: UUID) async throws -> TranslationOutput { calls += 1; if suspend { return try await withCheckedThrowingContinuation { pending.append($0) } }; if let issue { throw issue }; return output }
}
@MainActor private final class Clipboard: ClipboardAccess { var text = "hello"; var writes = 0; var reads = 0; func readText() -> String? { reads += 1; return text }; func writeText(_ text: String) { writes += 1; self.text = text } }
@MainActor private func drain() async { for _ in 0..<20 { await Task.yield() } }

@Suite @MainActor struct WorkflowTests {
    @Test func clipboardChangesOnlyOnExplicitCopy() async {
        let s = Selection(), e = Engine(), c = Clipboard(); let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c)
        w.start(mode: .clipboard, source: "en", target: "fr"); await drain()
        #expect(c.writes == 0); #expect(c.text == "hello"); w.copyResult(); #expect(c.writes == 1); #expect(c.text == "bonjour")
    }
    @Test func replacementFailureRetainsOutputAndWhitespace() async {
        let s = Selection(), e = Engine(), c = Clipboard(); s.failure = true
        let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c); w.start(mode: .replace, source: "en", target: "fr"); await drain()
        guard case let .showingResult(r) = w.state else { Issue.record("Expected retained result"); return }
        #expect(r.translation.text == "  bonjour \n"); #expect(r.replacementFailure != nil); #expect(!r.wasReplaced); #expect(c.writes == 0)
    }
    @Test func explicitSameLanguagePreservesExactlyWithoutEngine() async {
        let s = Selection(), e = Engine(), c = Clipboard(); let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c)
        w.start(mode: .selection, source: "en", target: "en"); await drain()
        guard case let .showingResult(r) = w.state else { Issue.record("Expected result"); return }; #expect(r.translation.text == s.text); #expect(e.calls == 0)
    }
    @Test func detectedSameLanguagePreservesExactly() async {
        let s = Selection(), e = Engine(), c = Clipboard(); e.output = .init(text: "changed", source: "en", target: "en")
        let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c); w.start(mode: .selection, source: nil, target: "en"); await drain()
        guard case let .showingResult(r) = w.state else { Issue.record("Expected result"); return }; #expect(r.translation.text == s.text)
    }
    @Test func modelsCanDisappearAfterSuccessNoAutomaticRetry() async {
        let e = Engine(); let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard())
        w.start(mode: .selection, source: "en", target: "fr"); await drain(); e.issue = .missingModels(.init(source: "en", target: "fr"))
        w.start(mode: .selection, source: "en", target: "fr"); await drain(); guard case .awaitingModelSetup = w.state else { Issue.record("Expected setup"); return }; #expect(e.calls == 2)
    }
    @Test func unsupportedPairIsFinalWithoutRetry() async {
        let e = Engine(); e.issue = .unsupportedPair(.init(source: "en", target: "xx")); let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard())
        w.start(mode: .selection, source: "en", target: "xx"); await drain(); guard case .failed = w.state else { Issue.record("Expected failure"); return }; #expect(e.calls == 1)
    }
    @Test func supersededCompletionCannotDeliverOrReplace() async {
        let e = Engine(), s = Selection(); e.suspend = true; let w = WorkflowCoordinator(selection: s, engine: e, clipboard: Clipboard())
        w.start(mode: .replace, source: "en", target: "fr"); await drain(); #expect(e.pending.count == 1)
        w.start(mode: .selection, source: "en", target: "de"); await drain(); #expect(e.pending.count == 2)
        e.pending[1].resume(returning: .init(text: "neu", source: "en", target: "de")); await drain()
        e.pending[0].resume(returning: .init(text: "old", source: "en", target: "fr")); await drain()
        guard case let .showingResult(r) = w.state else { Issue.record("Expected newer result"); return }; #expect(r.translation.target == "de"); #expect(s.replacements.isEmpty)
    }
    @Test func cancellationRejectsLateCompletion() async {
        let e = Engine(); e.suspend = true; let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard())
        w.start(mode: .replace, source: "en", target: "fr"); await drain(); w.cancel(); e.pending[0].resume(returning: e.output); await drain(); #expect(w.state == .idle)
    }
    @Test func emptyWhitespaceDoesNotTranslate() async {
        let s = Selection(), e = Engine(); s.text = " \n"; let w = WorkflowCoordinator(selection: s, engine: e, clipboard: Clipboard()); w.start(mode: .selection, source: nil, target: "fr"); await drain(); #expect(e.calls == 0); guard case .failed = w.state else { Issue.record("Expected failure"); return }
    }
    @Test func retryAfterSetupStillValidatesSelection() async {
        let s = Selection(), e = Engine(), c = Clipboard(); e.issue = .missingModels(.init(source: "en", target: "fr"))
        let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c); w.start(mode: .replace, source: "en", target: "fr"); await drain()
        let firstID = w.activeRequestID; s.failure = true; e.issue = nil; w.retry(); await drain()
        #expect(w.activeRequestID != firstID); guard case let .showingResult(result) = w.state else { Issue.record("Expected result"); return }
        #expect(!result.wasReplaced); #expect(result.replacementFailure != nil); #expect(s.replacements.isEmpty); #expect(c.writes == 0)
    }
    @Test func uncertainDetectionCanBeCorrectedManually() async {
        let e = Engine(); e.issue = .uncertainSource; let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard())
        w.start(mode: .selection, source: nil, target: "fr"); await drain(); e.issue = nil; w.retry(source: "en"); await drain()
        guard case let .showingResult(result) = w.state else { Issue.record("Expected corrected result"); return }; #expect(result.request.source == "en"); #expect(e.calls == 2)
    }
    @Test func explicitSourceCanBeResetToAutomaticOnRetry() async {
        let e = Engine(); let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard())
        w.start(mode: .selection, source: "en", target: "fr"); await drain()
        w.retry(automaticSource: true); await drain()
        guard case let .showingResult(result) = w.state else { Issue.record("Expected result"); return }
        #expect(result.request.source == nil)
    }
    @Test func failedSelectionCaptureNeverFallsBackToClipboard() async {
        let s = Selection(), c = Clipboard(), e = Engine(); s.captureFailure = true
        let w = WorkflowCoordinator(selection: s, engine: e, clipboard: c); w.start(mode: .selection, source: nil, target: "fr"); await drain()
        #expect(c.reads == 0); #expect(c.writes == 0); #expect(e.calls == 0)
    }
    @Test func sameLanguageReplacementStillValidatesContext() async {
        let s = Selection(), e = Engine(); s.failure = true
        let w = WorkflowCoordinator(selection: s, engine: e, clipboard: Clipboard()); w.start(mode: .replace, source: "en", target: "en"); await drain()
        guard case let .showingResult(r) = w.state else { Issue.record("Expected result"); return }; #expect(r.replacementFailure != nil); #expect(!r.wasReplaced); #expect(e.calls == 0)
    }
    @Test func cancellationDuringCaptureRejectsLateSelection() async {
        let s = SuspendedSelection(), e = Engine(); let w = WorkflowCoordinator(selection: s, engine: e, clipboard: Clipboard())
        w.start(mode: .selection, source: nil, target: "fr"); await drain(); let id = w.activeRequestID!; w.cancel()
        s.pending?.resume(returning: .init(requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: nil, isEditable: false)); await drain()
        #expect(w.state == .idle); #expect(e.calls == 0)
    }
    @Test func milestonesTrackSupersessionCancellationAndRetry() async {
        let e = Engine(); e.suspend = true; let w = WorkflowCoordinator(selection: Selection(), engine: e, clipboard: Clipboard()); var events: [(UUID, String)] = []
        w.onMilestone = { events.append(($0, $1)) }; w.start(mode: .selection, source: "en", target: "fr"); await drain(); let first = w.activeRequestID!
        w.start(mode: .selection, source: "en", target: "de"); await drain(); let second = w.activeRequestID!; w.cancel()
        #expect(events.contains { $0.0 == first && $0.1 == "superseded" }); #expect(events.contains { $0.0 == second && $0.1 == "cancelled" })
        e.pending[0].resume(returning: e.output); e.pending[1].resume(returning: e.output); await drain(); #expect(w.state == .idle)
        e.suspend = false; e.issue = .uncertainSource; w.start(mode: .selection, source: nil, target: "fr"); await drain(); e.issue = nil; w.retry(source: "en"); let retry = w.activeRequestID!; await drain()
        #expect(events.contains { $0.0 == retry && $0.1 == "shortcut_received" }); #expect(events.contains { $0.0 == retry && $0.1 == "retry_started" }); #expect(events.contains { $0.0 == retry && $0.1 == "result_ready" })
    }
    @Test func replacementValidationRejectsEveryContextMutation() {
        let id = UUID(), token = UUID(); let original = SelectionSnapshot(token: token, requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: .init(location: 1, length: 5), isEditable: true)
        func valid(_ current: SelectionSnapshot?, focus: Bool = true, active: UUID? = id) -> Bool { SelectionValidation.allowsReplacement(original: original, current: current, focused: focus, requestID: id, activeRequestID: active) }
        #expect(valid(original)); #expect(!valid(nil)); #expect(!valid(original, focus: false)); #expect(!valid(original, active: UUID()))
        let mutations = [SelectionSnapshot(token: UUID(), requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: original.range, isEditable: true), .init(token: token, requestID: id, text: "changed", applicationBundleID: "test", processID: 42, range: original.range, isEditable: true), .init(token: token, requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: .init(location: 2, length: 5), isEditable: true), .init(token: token, requestID: id, text: "hello", applicationBundleID: "test", processID: 43, range: original.range, isEditable: true), .init(token: token, requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: nil, isEditable: true), .init(token: token, requestID: id, text: "hello", applicationBundleID: "test", processID: 42, range: original.range, isEditable: false)]
        for mutation in mutations { #expect(!valid(mutation)) }
    }

}

@MainActor private final class SuspendedSelection: SelectionAccess {
    var pending: CheckedContinuation<SelectionSnapshot, any Error>?
    func capture(requestID: UUID) async throws -> SelectionSnapshot { try await withCheckedThrowingContinuation { pending = $0 } }
    func replace(snapshot: SelectionSnapshot, with text: String, requestID: UUID, isCurrent: @escaping @MainActor () -> Bool) async throws { throw TranslationIssue.failed }
}
