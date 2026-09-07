import AppKit
import Foundation

@MainActor
final class CodexAccountController: ObservableObject {
    static let shared = CodexAccountController(client: .shared)

    enum State: Equatable {
        case idle
        case checking
        case disconnected
        case connecting
        case connected(plan: String?, lunaAvailable: Bool)
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let client: CodexAppServerClient
    private var task: Task<Void, Never>?

    init(client: CodexAppServerClient) {
        self.client = client
    }

    deinit {
        task?.cancel()
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Not checked"
        case .checking:
            return "Checking Codex…"
        case .disconnected:
            return "Connect your ChatGPT account"
        case .connecting:
            return "Finish sign-in in your browser…"
        case .connected(let plan, let lunaAvailable):
            guard lunaAvailable else { return "The rewrite model is unavailable on this account" }
            return plan.map { "Connected · \($0.capitalized)" } ?? "Connected"
        case .unavailable:
            return "Install or update the Codex app"
        case .failed(let message):
            return message
        }
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var isLunaReady: Bool {
        if case .connected(_, true) = state { return true }
        return false
    }

    var canConnect: Bool {
        switch state {
        case .disconnected, .failed:
            true
        default:
            false
        }
    }

    func refresh() {
        task?.cancel()
        state = .checking
        task = Task { [client] in
            do {
                let snapshot = try await withCodexAccountDeadline {
                    try await client.accountSnapshot(forceRefresh: true)
                }
                guard !Task.isCancelled else { return }
                if snapshot.isConnected {
                    state = .connected(
                        plan: snapshot.plan,
                        lunaAvailable: snapshot.lunaAvailable
                    )
                } else {
                    state = .disconnected
                }
            } catch CodexRewriteError.runtimeUnavailable {
                state = .unavailable
            } catch is CancellationError {
                return
            } catch {
                state = .failed("Codex could not be reached")
            }
        }
    }

    func connect() {
        task?.cancel()
        state = .connecting
        task = Task { [client] in
            do {
                let login = try await withCodexAccountDeadline {
                    try await client.beginChatGPTLogin()
                }
                guard !Task.isCancelled else { return }
                NSWorkspace.shared.open(login.authorizationURL)

                for _ in 0..<60 {
                    try await Task.sleep(for: .seconds(1.5))
                    let snapshot = try await withCodexAccountDeadline {
                        try await client.accountSnapshot(forceRefresh: true)
                    }
                    guard !Task.isCancelled else { return }
                    if snapshot.isConnected {
                        state = .connected(
                            plan: snapshot.plan,
                            lunaAvailable: snapshot.lunaAvailable
                        )
                        return
                    }
                }
                state = .failed("Codex sign-in timed out. Try again.")
            } catch is CancellationError {
                return
            } catch CodexRewriteError.runtimeUnavailable {
                state = .unavailable
            } catch {
                state = .failed("Codex sign-in could not start")
            }
        }
    }

    func disconnect() {
        task?.cancel()
        state = .checking
        task = Task { [client] in
            do {
                try await withCodexAccountDeadline {
                    try await client.logout()
                }
                state = .disconnected
            } catch is CancellationError {
                return
            } catch {
                state = .failed("Codex could not sign out")
            }
        }
    }
}

private func withCodexAccountDeadline<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(for: .seconds(8))
            throw CodexRewriteError.attemptTimedOut
        }
        defer { group.cancelAll() }
        guard let value = try await group.next() else {
            throw CodexRewriteError.transportUnavailable
        }
        return value
    }
}
