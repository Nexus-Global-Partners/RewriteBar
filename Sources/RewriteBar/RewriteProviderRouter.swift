import Foundation
import OSLog
import RewriteCore

struct RewriteProviderRouter: RewriteGenerating, Sendable {
    static let shared = RewriteProviderRouter(
        local: LocalModelService.shared,
        codex: CodexRewriteService.shared
    )

    private let local: any RewriteGenerating
    private let codex: any RewriteGenerating
    private let codexAttemptSeconds: Double
    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "RewriteProviderRouter"
    )

    init(
        local: any RewriteGenerating,
        codex: any RewriteGenerating,
        codexAttemptSeconds: Double = 7
    ) {
        self.local = local
        self.codex = codex
        self.codexAttemptSeconds = codexAttemptSeconds
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        guard request.provider == .codexLuna else {
            return try await local.rewrite(
                request: request,
                onProgress: onProgress
            )
        }

        do {
            return try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await codex.rewrite(
                        request: request,
                        onProgress: onProgress
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(codexAttemptSeconds))
                    throw CodexRewriteError.attemptTimedOut
                }

                defer { group.cancelAll() }
                guard let result = try await group.next() else {
                    throw CodexRewriteError.transportUnavailable
                }
                return result
            }
        } catch is CancellationError {
            throw RewriteError.cancelled
        } catch let error as RewriteError where error == .cancelled {
            throw error
        } catch {
            logger.notice(
                "Online rewrite unavailable; retrying with the on-device model"
            )
            try Task.checkCancellation()
            return try await local.rewrite(
                request: request,
                onProgress: onProgress
            )
        }
    }
}
