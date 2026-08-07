import Foundation

/// Serializes access to the local model without allowing cancellation to strand the queue.
actor GenerationArbiter {
    struct Permit: Equatable, Sendable {
        fileprivate let id: UUID
    }

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Permit, Error>
    }

    private var activePermit: Permit?
    private var waiters: [Waiter] = []

    var queuedRequestCount: Int { waiters.count }

    func acquire() async throws -> Permit {
        try Task.checkCancellation()

        if activePermit == nil {
            let permit = Permit(id: UUID())
            activePermit = permit
            return permit
        }

        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Permit, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters.append(
                    Waiter(
                        id: waiterID,
                        continuation: continuation
                    )
                )
            }
        } onCancel: {
            Task { await self.cancel(waiterID) }
        }
    }

    func release(_ permit: Permit) {
        guard activePermit == permit else { return }

        guard !waiters.isEmpty else {
            activePermit = nil
            return
        }

        let waiter = waiters.removeFirst()
        let nextPermit = Permit(id: UUID())
        activePermit = nextPermit
        waiter.continuation.resume(returning: nextPermit)
    }

    private func cancel(_ waiterID: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == waiterID }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
