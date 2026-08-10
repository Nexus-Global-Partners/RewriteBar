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
    private let generationArbiter = GenerationArbiter()
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

            let permit = try await generationArbiter.acquire()
            do {
                try Task.checkCancellation()
                let preparedInput = try await modelContainer.prepare(input: input)
                let stream = try await modelContainer.generate(
                    input: preparedInput,
                    parameters: generationParameters(maxTokens: 12)
                )

                for await _ in stream {
                    try Task.checkCancellation()
                }
                await generationArbiter.release(permit)
            } catch {
                await generationArbiter.release(permit)
                throw error
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
        customInstructionsExclusive: Bool = false,
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async throws -> String {
        try await prepareModel()
        let personalizedResult = try await generate(
            text: text,
            intensity: intensity,
            customInstructions: customInstructions,
            systemPrompt: RewritePromptBuilder.systemPrompt,
            makeUserPrompt: { protectedSource in
                RewritePromptBuilder.userPrompt(
                    text: protectedSource.text,
                    intensity: intensity,
                    writingStyle: writingStyle,
                    customInstructions: customInstructions,
                    customInstructionsExclusive: customInstructionsExclusive,
                    protectedTokens: protectedSource.placeholderTokens
                )
            },
            onProgress: onProgress
        )
        guard RewriteOutputQualityPolicy.needsUnpersonalizedRetry(
            source: text,
            output: personalizedResult,
            intensity: intensity,
            customInstructions: customInstructions
        ) else {
            return personalizedResult
        }

        return try await generate(
            text: text,
            intensity: intensity,
            customInstructions: customInstructions,
            systemPrompt: RewritePromptBuilder.systemPrompt,
            makeUserPrompt: { protectedSource in
                RewritePromptBuilder.userPrompt(
                    text: protectedSource.text,
                    intensity: intensity,
                    writingStyle: customInstructionsExclusive
                        ? .rewriteBar
                        : writingStyle,
                    customInstructions: nil,
                    customInstructionsExclusive: false,
                    protectedTokens: protectedSource.placeholderTokens
                )
            },
            onProgress: onProgress
        )
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async throws -> String {
        try await rewrite(
            text: request.text,
            intensity: request.intensity,
            writingStyle: request.writingStyle,
            customInstructions: request.customInstructions,
            customInstructionsExclusive: request.customInstructionsExclusive,
            onProgress: onProgress
        )
    }

    private func generate(
        text: String,
        intensity: Int,
        customInstructions: String?,
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

        let permit = try await generationArbiter.acquire()
        do {
            try Task.checkCancellation()
            let maximumTokens = RewritePromptBuilder.maximumOutputTokens(for: text)
            let firstOutput = try await streamOutput(
                input: input,
                maxTokens: maximumTokens,
                onProgress: onProgress,
                using: modelContainer
            )
            var result = try finalizedOutput(
                firstOutput,
                protectedSource: protectedSource,
                source: text,
                intensity: intensity,
                customInstructions: customInstructions
            )
            var fidelity = OutputFidelityValidator.evaluate(
                source: text,
                output: result
            )

            if !fidelity.preservesMeaningSignals {
                logger.warning(
                    "Generated rewrite failed fidelity validation; using the safe source fallback"
                )
                result = try OutputSanitizer.sanitizeSourceFallback(text)
                fidelity = OutputFidelityValidator.evaluate(
                    source: text,
                    output: result
                )
            }

            guard fidelity.preservesMeaningSignals else {
                throw RewriteError.generationFailed
            }
            Memory.clearCache()
            await generationArbiter.release(permit)
            return result
        } catch is CancellationError {
            await generationArbiter.release(permit)
            Memory.clearCache()
            throw RewriteError.cancelled
        } catch let error as RewriteError {
            await generationArbiter.release(permit)
            Memory.clearCache()
            throw error
        } catch {
            await generationArbiter.release(permit)
            Memory.clearCache()
            throw RewriteError.generationFailed
        }
    }

    private func streamOutput(
        input: sending UserInput,
        maxTokens: Int,
        onProgress: (@Sendable (Int) async -> Void)?,
        using modelContainer: ModelContainer
    ) async throws -> String {
        let preparedInput = try await modelContainer.prepare(input: input)
        let stream = try await modelContainer.generate(
            input: preparedInput,
            parameters: generationParameters(maxTokens: maxTokens)
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
        return output
    }

    private func finalizedOutput(
        _ output: String,
        protectedSource: ProtectedSource,
        source: String,
        intensity: Int,
        customInstructions: String?
    ) throws -> String {
        guard let restored = protectedSource.restoringProtectedContent(
            in: output
        ) else {
            throw RewriteError.generationFailed
        }
        let sanitized = try OutputSanitizer.sanitize(restored)
        let withoutFraming = OutputStyleGuard.removingIntroducedFraming(
            from: sanitized,
            source: source
        )
        let withoutOfficeFiller = OutputStyleGuard.replacingOfficeFiller(
            in: withoutFraming,
            source: source,
            intensity: intensity
        )
        let withUncertainty = OutputStyleGuard.restoringUncertaintyStrength(
            in: withoutOfficeFiller,
            source: source
        )
        let withCommitment = OutputStyleGuard.restoringCommitmentStrength(
            in: withUncertainty,
            source: source
        )
        return RewriteCustomInstructionsPolicy.applyingPresentation(
            to: withCommitment,
            source: source,
            instructions: customInstructions
        )
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

}

extension LocalModelService: RewriteGenerating {}
