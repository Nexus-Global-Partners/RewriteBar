import Foundation
import RewriteCore

struct RewriteRequest: Equatable, Sendable {
    let text: String
    let intensity: Int
    let writingStyle: RewriteStyle
    let customInstructions: String?
    let customInstructionsExclusive: Bool

    init(
        text: String,
        intensity: Int,
        writingStyle: RewriteStyle = .rewriteBar,
        customInstructions: String? = nil,
        customInstructionsExclusive: Bool = false
    ) {
        self.text = text
        self.intensity = RewriteIntensityPolicy.clampedLevel(intensity)
        self.writingStyle = writingStyle
        self.customInstructions = RewriteCustomInstructionsPolicy.normalized(
            customInstructions
        )
        self.customInstructionsExclusive = self.customInstructions != nil
            && customInstructionsExclusive
    }
}

protocol RewriteGenerating: Sendable {
    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String
}

struct RewriteEngine: Sendable {
    static let shared = RewriteEngine(generator: LocalModelService.shared)

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
