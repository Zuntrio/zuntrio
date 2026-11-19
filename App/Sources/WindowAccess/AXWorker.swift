import Foundation

/// Runs Accessibility work on one serial background queue, so a slow or hung
/// app can never block the main thread (menus, settings, other shortcuts).
/// Serial: calls never overlap, matching how actions are applied one by one.
final class AXWorker: Sendable {
    private let queue = DispatchQueue(label: "app.zuntrio.Zuntrio.accessibility", qos: .userInitiated)

    func run<T: Sendable>(
        _ body: @escaping @Sendable () throws(WindowAccessError) -> T
    ) async throws(WindowAccessError) -> T {
        let result: Result<T, WindowAccessError> = await withCheckedContinuation { continuation in
            queue.async {
                do throws(WindowAccessError) {
                    continuation.resume(returning: .success(try body()))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
        return try result.get()
    }
}
