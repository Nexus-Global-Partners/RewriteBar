import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import OSLog
import RewriteCore

actor LocalModelService {
    static let shared = LocalModelService()

    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "LocalModelService"
    )
    private var modelContainer: ModelContainer?
    private var modelPreparationTask: Task<ModelContainer, Error>?
    private var isGenerationActive = false
    private struct GenerationWaiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }
    private var generationWaiters: [GenerationWaiter] = []
    private var isWarmedUp = false

    init() {
        Memory.cacheLimit = AppConstants.modelCacheLimitBytes
    }

    func warmUp() async {
        guard !isWarmedUp else { return }
        logger.notice("Model warm-up started")

        do {
            try await prepareModel()
            guard let modelContainer else { return }
            logger.notice("Model loaded; running warm-up generation")

            let input = UserInput(
                chat: [
                    .system(RewritePromptBuilder.systemPrompt),
                    .user(
                        RewritePromptBuilder.userPrompt(
                            text: "Warm up this sentence.",
                            intensity: 1
                        )
                    )
                ],
                additionalContext: ["enable_thinking": false]
            )

            try await acquireGenerationSlot()
            defer { releaseGenerationSlot() }
            try Task.checkCancellation()

            let preparedInput = try await modelContainer.prepare(input: input)
            let stream = try await modelContainer.generate(
                input: preparedInput,
                parameters: generationParameters(maxTokens: 12)
            )

            for await _ in stream {
                try Task.checkCancellation()
            }
            isWarmedUp = true
            logger.notice("Model warm-up completed")
        } catch is CancellationError {
            return
        } catch let error as RewriteError where error == .cancelled {
            return
        } catch {
            logger.warning("Model warm-up failed: \(String(reflecting: error), privacy: .public)")
        }
    }

    func prepareModel() async throws {
        if modelContainer != nil {
            return
        }

        guard ModelLocation.isModelInstalled() else {
            throw RewriteError.modelUnavailable
        }

        if let modelPreparationTask {
            do {
                modelContainer = try await modelPreparationTask.value
                try Task.checkCancellation()
                return
            } catch is CancellationError {
                throw RewriteError.cancelled
            } catch {
                logger.error("Shared model preparation failed: \(String(reflecting: error), privacy: .public)")
                throw RewriteError.modelLoadFailed
            }
        }

        let preparationTask = Task {
            try await LLMModelFactory.shared.loadContainer(
                configuration: ModelConfiguration(directory: ModelLocation.repositoryURL)
            )
        }
        modelPreparationTask = preparationTask

        do {
            let container = try await preparationTask.value
            modelPreparationTask = nil
            modelContainer = container
            try Task.checkCancellation()
        } catch is CancellationError {
            modelPreparationTask = nil
            throw RewriteError.cancelled
        } catch {
            modelPreparationTask = nil
            logger.error("Model preparation failed: \(String(reflecting: error), privacy: .public)")
            throw RewriteError.modelLoadFailed
        }
    }

    func rewrite(
        text: String,
        intensity: Int,
        writingStyle: RewriteStyle = .rewriteBar,
        customInstructions: String? = nil,
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async throws -> String {
        try await prepareModel()
        return try await generate(
            text: text,
            intensity: intensity,
            systemPrompt: RewritePromptBuilder.systemPrompt,
            makeUserPrompt: { protectedSource in
                RewritePromptBuilder.userPrompt(
                    text: protectedSource.text,
                    intensity: intensity,
                    writingStyle: writingStyle,
                    customInstructions: customInstructions,
                    protectedTokens: protectedSource.placeholderTokens
                )
            },
            onProgress: onProgress
        )
    }

    private func generate(
        text: String,
        intensity: Int,
        systemPrompt: String,
        makeUserPrompt: (ProtectedSource) -> String,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        guard let modelContainer else {
            throw RewriteError.modelUnavailable
        }

        let protectedSource = SourceInstructionProtector.protect(text)

        let input = UserInput(
            chat: [
                .system(systemPrompt),
                .user(makeUserPrompt(protectedSource))
            ],
            additionalContext: ["enable_thinking": false]
        )

        try await acquireGenerationSlot()
        defer { releaseGenerationSlot() }

        do {
            try Task.checkCancellation()
            let preparedInput = try await modelContainer.prepare(input: input)
            let stream = try await modelContainer.generate(
                input: preparedInput,
                parameters: generationParameters(
                    maxTokens: RewritePromptBuilder.maximumOutputTokens(for: text)
                )
            )

            var output = ""
            var generatedCharacterCount = 0
            var lastReportedCharacterCount = 0
            var lastProgressUpdate = Date.distantPast
            var reachedTokenLimit = false
            for await event in stream {
                try Task.checkCancellation()
                switch event {
                case .chunk(let chunk):
                    output.append(chunk)
                    generatedCharacterCount += chunk.count
                    let now = Date()
                    if generatedCharacterCount - lastReportedCharacterCount >= 24,
                       now.timeIntervalSince(lastProgressUpdate) >= 0.08 {
                        lastReportedCharacterCount = generatedCharacterCount
                        lastProgressUpdate = now
                        await onProgress?(generatedCharacterCount)
                    }
                case .info(let info):
                    if case .length = info.stopReason {
                        reachedTokenLimit = true
                    }
                case .toolCall:
                    break
                }
            }

            await onProgress?(generatedCharacterCount)
            guard !reachedTokenLimit else {
                throw RewriteError.generationFailed
            }

            Memory.clearCache()
            let restored = protectedSource.restoringProtectedContent(in: output)
                ?? text
            let sanitized = try OutputSanitizer.sanitize(restored)
            let withoutFraming = OutputStyleGuard.removingIntroducedFraming(
                from: sanitized,
                source: text
            )
            let withoutOfficeFiller = OutputStyleGuard.replacingOfficeFiller(
                in: withoutFraming,
                source: text,
                intensity: intensity
            )
            return OutputStyleGuard.restoringUncertaintyStrength(
                in: withoutOfficeFiller,
                source: text
            )
        } catch is CancellationError {
            Memory.clearCache()
            throw RewriteError.cancelled
        } catch let error as RewriteError {
            Memory.clearCache()
            throw error
        } catch {
            Memory.clearCache()
            throw RewriteError.generationFailed
        }
    }

    private func generationParameters(maxTokens: Int) -> GenerateParameters {
        GenerateParameters(
            maxTokens: maxTokens,
            kvBits: 8,
            temperature: 0,
            repetitionPenalty: 1.03,
            repetitionContextSize: 64,
            prefillStepSize: 512
        )
    }

    private func acquireGenerationSlot() async throws {
        try Task.checkCancellation()
        if !isGenerationActive {
            isGenerationActive = true
            return
        }

        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                generationWaiters.append(
                    GenerationWaiter(
                        id: waiterID,
                        continuation: continuation
                    )
                )
            }
        } onCancel: {
            Task { await self.cancelGenerationWaiter(waiterID) }
        }
        try Task.checkCancellation()
    }

    private func releaseGenerationSlot() {
        guard !generationWaiters.isEmpty else {
            isGenerationActive = false
            return
        }

        generationWaiters.removeFirst().continuation.resume()
    }

    private func cancelGenerationWaiter(_ waiterID: UUID) {
        guard let index = generationWaiters.firstIndex(where: { $0.id == waiterID }) else {
            return
        }
        let waiter = generationWaiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
