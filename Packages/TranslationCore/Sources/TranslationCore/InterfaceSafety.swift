/// Owns the same transaction used by the Carbon adapter and deterministic tests.
/// The old registration remains active until the replacement has registered.
@MainActor public final class ShortcutTransaction<Value: Equatable, Handle> {
    public private(set) var active: Value?
    private var handle: Handle?
    private var pendingCleanup: Handle?
    public init() {}

    public func change(to value: Value?, register: (Value) throws -> Handle,
                       remove: (Handle) throws -> Void, persist: (Value?) -> Void) throws {
        // A failed rollback stays owned and must be cleaned up before another edit.
        if let pendingCleanup { try remove(pendingCleanup); self.pendingCleanup = nil }
        guard active != value else { return }
        let replacement = try value.map(register)
        if let handle {
            do { try remove(handle) }
            catch {
                if let replacement {
                    do { try remove(replacement) }
                    catch { pendingCleanup = replacement; throw ShortcutTransactionError.rollbackFailed }
                }
                throw error
            }
        }
        handle = replacement
        active = value
        persist(value)
    }
}

public enum ShortcutTransactionError: Error { case rollbackFailed }
