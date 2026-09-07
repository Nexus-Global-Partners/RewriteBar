import Foundation
import RewriteCore

/// One online attempt, within RewriteEngine's overall deadline. No model downloads or fallback.
struct RewriteProviderRouter: RewriteGenerating, Sendable {
    static let shared = RewriteProviderRouter(codex: CodexRewriteService.shared)
    private let codex: any RewriteGenerating

    init(codex: any RewriteGenerating) { self.codex = codex }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        do {
            return try await codex.rewrite(request: request, onProgress: onProgress)
        } catch is CancellationError {
            throw RewriteError.cancelled
        } catch let error as CodexRewriteError {
            switch error {
            case .notConnected: throw RewriteError.accountRequired
            case .runtimeUnavailable: throw RewriteError.runtimeRequired
            case .lunaUnavailable: throw RewriteError.modelUnavailable
            case .usageLimitReached: throw RewriteError.usageLimitReached
            case .transportUnavailable: throw RewriteError.connectionFailed
            case .attemptTimedOut: throw RewriteError.timedOut
            case .busy: throw RewriteError.generationFailed
            case .protocolViolation, .unexpectedToolRequest, .serverFailure:
                throw RewriteError.generationFailed
            }
        }
    }
}
