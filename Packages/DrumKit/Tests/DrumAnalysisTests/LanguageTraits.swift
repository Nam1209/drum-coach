import DrumCore
import Testing

/// Runs a test with the app language forced to Vietnamese (task-local, safe with parallel tests).
struct VietnameseTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        try await Lang.$override.withValue(.vi) { try await function() }
    }
}
extension Trait where Self == VietnameseTrait { static var vietnamese: Self { VietnameseTrait() } }
