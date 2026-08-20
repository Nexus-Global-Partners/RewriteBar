import Foundation
import RewriteCore

enum RewriteProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case local
    case codexLuna

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local:
            "On this Mac"
        case .codexLuna:
            "Codex Luna (online)"
        }
    }
}

struct RewriteRequest: Equatable, Sendable {
    let text: String
    let intensity: Int
    let writingStyle: RewriteStyle
    let customInstructions: String?
    let customInstructionsExclusive: Bool
    let provider: RewriteProvider

    init(
        text: String,
        intensity: Int,
        writingStyle: RewriteStyle = .rewriteBar,
        customInstructions: String? = nil,
        customInstructionsExclusive: Bool = false,
        provider: RewriteProvider = .local
    ) {
        self.text = text
        self.intensity = RewriteIntensityPolicy.clampedLevel(intensity)
        self.writingStyle = writingStyle
        self.customInstructions = RewriteCustomInstructionsPolicy.normalized(
            customInstructions
        )
        self.customInstructionsExclusive = self.customInstructions != nil
            && customInstructionsExclusive
        self.provider = provider
    }
}

protocol RewriteGenerating: Sendable {
    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String
}

struct RewriteEngine: Sendable {
    static let shared = RewriteEngine(generator: RewriteProviderRouter.shared)

    private let generator: any RewriteGenerating
    private let timeoutSeconds: @Sendable (Int) -> Double

    init(
        generator: any RewriteGenerating,
        timeoutSeconds: @escaping @Sendable (Int) -> Double = {
            PreparationPolicy.timeoutSeconds(forCharacterCount: $0)
        }
    ) {
        self.generator = generator
        self.timeoutSeconds = timeoutSeconds
    }

    func rewrite(
        _ request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async throws -> String {
        let timeout = timeoutSeconds(request.text.count)

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await generator.rewrite(
                    request: request,
                    onProgress: onProgress
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw RewriteError.timedOut
            }

            defer { group.cancelAll() }
            guard let output = try await group.next() else {
                throw RewriteError.generationFailed
            }
            return output
        }
    }
}
