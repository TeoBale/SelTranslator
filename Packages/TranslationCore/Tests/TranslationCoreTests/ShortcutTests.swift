import Testing
@testable import TranslationCore

@MainActor struct ShortcutTests {
    enum Failure: Error { case registration, removal }
    @Test func transactionKeepsRegisteredDisplayedAndPersistedValuesConsistent() throws {
        let transaction = ShortcutTransaction<Int, Int>()
        var registered: Set<Int> = []
        var displayed: Int?
        var persisted: [Int?] = []
        var failRegistration = false
        var failRemoval: Int?
        func change(_ value: Int?) throws {
            try transaction.change(to: value, register: { key in
                if failRegistration { throw Failure.registration }
                registered.insert(key); return key
            }, remove: { handle in
                if failRemoval == handle { throw Failure.removal }
                registered.remove(handle)
            }, persist: { value in displayed = value; persisted.append(value) })
        }
        try change(1)
        failRegistration = true
        #expect(throws: Failure.self) { try change(2) }
        #expect(registered == [1]); #expect(transaction.active == 1)
        #expect(displayed == 1); #expect(persisted == [1])
        failRegistration = false; failRemoval = 1
        #expect(throws: Failure.self) { try change(2) }
        #expect(registered == [1]); #expect(transaction.active == 1)
        #expect(displayed == 1); #expect(persisted == [1])
        #expect(throws: Failure.self) { try change(nil) }
        #expect(registered == [1]); #expect(displayed == 1)
        failRemoval = nil
        try change(2)
        #expect(registered == [2]); #expect(transaction.active == 2)
        #expect(displayed == 2); #expect(persisted == [1, 2])
        try change(2); #expect(persisted == [1, 2])
        try change(nil)
        #expect(registered.isEmpty); #expect(transaction.active == nil)
        #expect(displayed == nil); #expect(persisted == [1, 2, nil])
    }
    @Test func failedRollbackRemainsOwnedForLaterCleanup() throws {
        let transaction = ShortcutTransaction<Int, Int>()
        var registered: Set<Int> = []
        var refuseRemoval = false
        var persisted: [Int?] = []
        func change(_ value: Int?) throws {
            try transaction.change(to: value, register: { registered.insert($0); return $0 }, remove: {
                if refuseRemoval { throw Failure.removal }; registered.remove($0)
            }, persist: { persisted.append($0) })
        }
        try change(1); refuseRemoval = true
        #expect(throws: ShortcutTransactionError.self) { try change(2) }
        #expect(registered == [1, 2]); #expect(transaction.active == 1); #expect(persisted == [1])
        refuseRemoval = false
        try change(3)
        #expect(registered == [3]); #expect(transaction.active == 3); #expect(persisted == [1, 3])
    }
}
