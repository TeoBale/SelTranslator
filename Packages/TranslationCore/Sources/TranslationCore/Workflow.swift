import Foundation
import Observation

public struct LanguagePair: Sendable, Equatable, Hashable {
    public let source: String
    public let target: String
    public init(source: String, target: String) { self.source = source; self.target = target }
}
public struct SelectionRange: Sendable, Equatable {
    public let location: Int
    public let length: Int
    public init(location: Int, length: Int) { self.location = location; self.length = length }
}
public struct SelectionSnapshot: Sendable, Equatable {
    public let token: UUID
    public let requestID: UUID
    public let text: String
    public let applicationBundleID: String
    public let processID: Int32
    public let range: SelectionRange?
    public let isEditable: Bool
    public init(token: UUID = UUID(), requestID: UUID, text: String, applicationBundleID: String, processID: Int32, range: SelectionRange?, isEditable: Bool) {
        self.token = token; self.requestID = requestID; self.text = text; self.applicationBundleID = applicationBundleID; self.processID = processID; self.range = range; self.isEditable = isEditable
    }
    public func forRequest(_ id: UUID) -> Self { .init(token: token, requestID: id, text: text, applicationBundleID: applicationBundleID, processID: processID, range: range, isEditable: isEditable) }
}
public struct TranslationOutput: Sendable, Equatable {
    public let text: String
    public let source: String
    public let target: String
    public init(text: String, source: String, target: String) { self.text = text; self.source = source; self.target = target }
}
public enum TranslationIssue: Error, Sendable, Equatable, LocalizedError {
    case emptyInput, uncertainSource, unsupportedPair(LanguagePair), missingModels(LanguagePair), failed, cancelled
    public var errorDescription: String? {
        switch self {
        case .emptyInput: "Select or copy some text first."
        case .uncertainSource: "The source language could not be determined. Choose a source language and retry."
        case .unsupportedPair: "Apple Translation does not support this language pair. Choose another language."
        case .missingModels: "Download the language models in Model Setup, then retry."
        case .failed: "Translation failed. Check model readiness and retry."
        case .cancelled: "Translation was cancelled."
        }
    }
}
public enum DeliveryMode: String, Sendable, Codable { case selection, replace, clipboard }
public struct RequestContext: Sendable, Equatable {
    public let id: UUID
    public let mode: DeliveryMode
    public let source: String?
    public let target: String
    public let text: String
    public let selection: SelectionSnapshot?
}
public struct WorkflowResult: Sendable, Equatable {
    public let request: RequestContext
    public let translation: TranslationOutput
    public let replacementFailure: String?
    public let wasReplaced: Bool
}
public enum WorkflowState: Sendable, Equatable {
    case idle, capturing(UUID), translating(RequestContext), awaitingModelSetup(RequestContext, LanguagePair), showingResult(WorkflowResult), failed(RequestContext?, String)
}
@MainActor public protocol SelectionAccess: AnyObject {
    func capture(requestID: UUID) async throws -> SelectionSnapshot
    func replace(snapshot: SelectionSnapshot, with text: String, requestID: UUID, isCurrent: @escaping @MainActor () -> Bool) async throws
}
@MainActor public protocol TranslationEngine: AnyObject {
    func translate(text: String, source: String?, target: String, requestID: UUID) async throws -> TranslationOutput
    func cancelActive()
}
public extension TranslationEngine { func cancelActive() {} }
@MainActor public protocol ClipboardAccess: AnyObject {
    func readText() -> String?
    func writeText(_ text: String)
}

/// Owns one request. System adapters must also check isCurrent immediately before a write.
@Observable @MainActor public final class WorkflowCoordinator {
    public private(set) var state: WorkflowState = .idle { didSet { onStateChange?(state) } }
    public private(set) var activeRequestID: UUID?
    @ObservationIgnored private let selection: any SelectionAccess
    @ObservationIgnored private let engine: any TranslationEngine
    @ObservationIgnored private let clipboard: any ClipboardAccess
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var retainedRequest: RequestContext?
    @ObservationIgnored public var onStateChange: (@MainActor (WorkflowState) -> Void)?
    @ObservationIgnored public var onMilestone: (@MainActor (UUID, String) -> Void)?
    public init(selection: any SelectionAccess, engine: any TranslationEngine, clipboard: any ClipboardAccess) { self.selection = selection; self.engine = engine; self.clipboard = clipboard }
    public func start(mode: DeliveryMode, source: String?, target: String) {
        stopActive(outcome: "superseded")
        let id = UUID(); activeRequestID = id; retainedRequest = nil
        onMilestone?(id, "shortcut_received")
        state = .capturing(id)
        task = Task { [weak self] in
            guard let self else { return }
            var context: RequestContext?
            do {
                let snapshot = mode == .clipboard ? nil : try await selection.capture(requestID: id)
                guard current(id) else { return }
                onMilestone?(id, "selection_captured")
                let text = mode == .clipboard ? (clipboard.readText() ?? "") : (snapshot?.text ?? "")
                let request = RequestContext(id: id, mode: mode, source: source, target: target, text: text, selection: snapshot)
                context = request; retainedRequest = request
                try await execute(request)
            } catch { finish(error, request: context, id: id) }
        }
    }
    public func retry(source: String? = nil, automaticSource: Bool = false) {
        guard let previous = retainedRequest else { return }
        stopActive(outcome: "superseded")
        let id = UUID(); activeRequestID = id
        onMilestone?(id, "shortcut_received")
        onMilestone?(id, "retry_started")
        let request = RequestContext(id: id, mode: previous.mode, source: automaticSource ? nil : (source ?? previous.source), target: previous.target, text: previous.text, selection: previous.selection?.forRequest(id))
        retainedRequest = request; state = .translating(request)
        task = Task { [weak self] in
            guard let self else { return }
            do { try await execute(request) } catch { finish(error, request: request, id: id) }
        }
    }
    public func cancel() { stopActive(outcome: "cancelled"); task = nil; activeRequestID = nil; retainedRequest = nil; state = .idle }
    public func copyResult() { if case let .showingResult(result) = state { clipboard.writeText(result.translation.text) } }
    private func stopActive(outcome: String) {
        if let id = activeRequestID {
            switch state {
            case .capturing, .translating: onMilestone?(id, outcome)
            default: break
            }
        }
        engine.cancelActive(); task?.cancel()
    }
    private func current(_ id: UUID) -> Bool { activeRequestID == id && !Task.isCancelled }
    private func execute(_ request: RequestContext) async throws {
        guard current(request.id) else { throw CancellationError() }
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TranslationIssue.emptyInput }
        state = .translating(request)
        let output: TranslationOutput
        if let source = request.source, source == request.target {
            output = .init(text: request.text, source: source, target: request.target)
        } else {
            let translated = try await engine.translate(text: request.text.trimmingCharacters(in: .whitespacesAndNewlines), source: request.source, target: request.target, requestID: request.id)
            guard current(request.id) else { throw CancellationError() }
            output = .init(text: translated.source == translated.target ? request.text : Whitespace.preserve(from: request.text, around: translated.text), source: translated.source, target: translated.target)
        }
        guard current(request.id) else { return }
        var failure: String?; var replaced = false
        if request.mode == .replace, let snapshot = request.selection {
            do {
                try await selection.replace(snapshot: snapshot, with: output.text, requestID: request.id, isCurrent: { [weak self] in self?.activeRequestID == request.id && !Task.isCancelled })
                replaced = true
            } catch {
                guard current(request.id) else { return }
                failure = (error as? LocalizedError)?.errorDescription ?? "The original selection could not be safely replaced. It may have changed or lost focus. The translation is available here to copy."
            }
        }
        guard current(request.id) else { return }
        onMilestone?(request.id, replaced ? "replacement_completed" : "result_ready")
        state = .showingResult(.init(request: request, translation: output, replacementFailure: failure, wasReplaced: replaced))
    }
    private func finish(_ error: any Error, request: RequestContext?, id: UUID) {
        guard current(id) else { return }
        if error is CancellationError || (error as? TranslationIssue) == .cancelled { onMilestone?(id, "cancelled"); state = .idle; return }
        if case let .missingModels(pair) = error as? TranslationIssue, let request { onMilestone?(id, "missing_models"); state = .awaitingModelSetup(request, pair) }
        else {
            let outcome: String
            switch error as? TranslationIssue {
            case .emptyInput: outcome = "empty_input"
            case .uncertainSource: outcome = "uncertain_source"
            case .unsupportedPair: outcome = "unsupported_pair"
            default: outcome = "failed"
            }
            onMilestone?(id, outcome)
            state = .failed(request, (error as? LocalizedError)?.errorDescription ?? "The operation failed. Check Accessibility access and retry.")
        }
    }
}
public enum Whitespace {
    public static func preserve(from original: String, around translated: String) -> String {
        let leading = original.prefix(while: { $0.isWhitespace })
        let trailing = original.reversed().prefix(while: { $0.isWhitespace }).reversed()
        return String(leading) + translated.trimmingCharacters(in: .whitespacesAndNewlines) + String(trailing)
    }
}
public enum SelectionValidation {
    public static func allowsReplacement(original: SelectionSnapshot, current: SelectionSnapshot?, focused: Bool, requestID: UUID, activeRequestID: UUID?) -> Bool {
        guard let current, focused, activeRequestID == requestID, original.requestID == requestID, current.requestID == requestID,
              original.isEditable, current.isEditable, let range = original.range, range.length > 0,
              original.token == current.token, original.applicationBundleID == current.applicationBundleID,
              original.processID == current.processID, original.text == current.text, range == current.range else { return false }
        return true
    }
}
