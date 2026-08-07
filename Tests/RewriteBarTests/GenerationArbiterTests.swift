import Testing
@testable import RewriteBar

@Test
func cancelledWaiterDoesNotBlockTheNextRequest() async throws {
    let arbiter = GenerationArbiter()
    let firstPermit = try await arbiter.acquire()

    let cancelledWaiter = Task {
        try await arbiter.acquire()
    }
    try await waitForQueueCount(1, in: arbiter)
    cancelledWaiter.cancel()
    try await waitForQueueCount(0, in: arbiter)

    await arbiter.release(firstPermit)
    do {
        _ = try await cancelledWaiter.value
        Issue.record("A cancelled waiter received a permit.")
    } catch is CancellationError {
    }

    let nextPermit = try await acquireWithTimeout(from: arbiter)
    await arbiter.release(nextPermit)
}

@Test
func promotedCancelledWaiterCanReleaseItsPermit() async throws {
    let arbiter = GenerationArbiter()
    let firstPermit = try await arbiter.acquire()

    let promotedWaiter = Task {
        let permit = try await arbiter.acquire()
        do {
            try Task.checkCancellation()
            await arbiter.release(permit)
        } catch {
            await arbiter.release(permit)
            throw error
        }
    }
    await Task.yield()
    await arbiter.release(firstPermit)
    promotedWaiter.cancel()

    do {
        try await promotedWaiter.value
    } catch is CancellationError {
    }

    let nextPermit = try await acquireWithTimeout(from: arbiter)
    await arbiter.release(nextPermit)
}

private func acquireWithTimeout(
    from arbiter: GenerationArbiter
) async throws -> GenerationArbiter.Permit {
    try await withThrowingTaskGroup(of: GenerationArbiter.Permit.self) { group in
        group.addTask {
            try await arbiter.acquire()
        }
        group.addTask {
            try await Task.sleep(for: .milliseconds(250))
            throw GenerationArbiterTestFailure.timedOut
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

private func waitForQueueCount(
    _ expected: Int,
    in arbiter: GenerationArbiter
) async throws {
    for _ in 0..<50 {
        if await arbiter.queuedRequestCount == expected {
            return
        }
        try await Task.sleep(for: .milliseconds(2))
    }
    throw GenerationArbiterTestFailure.timedOut
}

private enum GenerationArbiterTestFailure: Error {
    case timedOut
}
