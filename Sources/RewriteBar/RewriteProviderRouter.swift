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
    private let codexAttemptSeconds: @Sendable (Int) -> Double
    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "RewriteProviderRouter"
    )

    init(
        local: any RewriteGenerating,
        codex: any RewriteGenerating,
        codexAttemptTimeout: @escaping @Sendable (Int) -> Double = {
            CodexAttemptPolicy.timeoutSeconds(forCharacterCount: $0)
        }
    ) {
        self.local = local
        self.codex = codex
        codexAttemptSeconds = codexAttemptTimeout
    }

    init(
        local: any RewriteGenerating,
        codex: any RewriteGenerating,
        codexAttemptSeconds: Double
    ) {
        self.init(
            local: local,
            codex: codex,
            codexAttemptTimeout: { _ in codexAttemptSeconds }
        )
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        guard request.provider == .codexLuna else {
            let startedAt = Date()
            let output = try await local.rewrite(
                request: request,
                onProgress: onProgress
            )
            guard RewriteOutputQualityPolicy.isVisibleCompletion(
                source: request.text,
                output: output,
                intensity: request.intensity
            ) else {
                throw RewriteError.generationFailed
            }
            logger.notice(
                "On-device rewrite completed in \(Date().timeIntervalSince(startedAt), privacy: .public) seconds"
            )
            return output
        }

        let onlineStartedAt = Date()
        do {
            let output = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await codex.rewrite(
                        request: request,
                        onProgress: onProgress
                    )
                }
                group.addTask {
                    try await Task.sleep(
                        for: .seconds(codexAttemptSeconds(request.text.count))
                    )
                    throw CodexRewriteError.attemptTimedOut
                }

                defer { group.cancelAll() }
                guard let result = try await group.next() else {
                    throw CodexRewriteError.transportUnavailable
                }
                return result
            }
            guard RewriteOutputQualityPolicy.isVisibleCompletion(
                source: request.text,
                output: output,
                intensity: request.intensity
            ) else {
                throw RewriteError.generationFailed
            }
            logger.notice(
                "Codex Luna rewrite completed in \(Date().timeIntervalSince(onlineStartedAt), privacy: .public) seconds"
            )
            return output
        } catch is CancellationError {
            throw RewriteError.cancelled
        } catch let error as RewriteError where error == .cancelled {
            throw error
        } catch {
            logger.notice(
                "Online rewrite unavailable after \(Date().timeIntervalSince(onlineStartedAt), privacy: .public) seconds; retrying with the on-device model"
            )
            try Task.checkCancellation()
            let fallbackStartedAt = Date()
            let output = try await local.rewrite(
                request: request,
                onProgress: onProgress
            )
            guard RewriteOutputQualityPolicy.isVisibleCompletion(
                source: request.text,
                output: output,
                intensity: request.intensity
            ) else {
                throw RewriteError.generationFailed
            }
            logger.notice(
                "On-device fallback completed in \(Date().timeIntervalSince(fallbackStartedAt), privacy: .public) seconds"
            )
            return output
        }
    }
}
