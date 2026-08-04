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
    private var releaseTask: Task<Void, Never>?
    private var isGenerationActive = false
    private var generationWaiters: [CheckedContinuation<Void, Never>] = []
    private var operationID = UUID()
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

            await acquireGenerationSlot()
            defer { releaseGenerationSlot() }
            try Task.checkCancellation()

            let preparedInput = try await modelContainer.prepare(input: input)
            let stream = try await modelContainer.generate(
                input: preparedInput,
                parameters: GenerateParameters(
                    maxTokens: 12,
                    kvBits: 8,
                    temperature: 0,
                    repetitionPenalty: 1.03,
                    repetitionContextSize: 64,
                    prefillStepSize: 512
                )
            )

            for await _ in stream {
                try Task.checkCancellation()
            }
            isWarmedUp = true
            logger.notice("Model warm-up completed")
            scheduleRelease()
        } catch is CancellationError {
            scheduleRelease()
        } catch let error as RewriteError where error == .cancelled {
            scheduleRelease()
        } catch {
            logger.warning("Model warm-up failed: \(String(reflecting: error), privacy: .public)")
        }
    }

    func prepareModel() async throws {
        if modelContainer != nil {
            scheduleRelease()
            return
        }

        guard ModelLocation.isModelInstalled() else {
            throw RewriteError.modelUnavailable
        }

        if let modelPreparationTask {
            do {
                modelContainer = try await modelPreparationTask.value
                try Task.checkCancellation()
                scheduleRelease()
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
            scheduleRelease()
        } catch is CancellationError {
            modelPreparationTask = nil
            throw RewriteError.cancelled
        } catch {
            modelPreparationTask = nil
            logger.error("Model preparation failed: \(String(reflecting: error), privacy: .public)")
            throw RewriteError.modelLoadFailed
        }
    }

    func rewrite(text: String, intensity: Int) async throws -> String {
        try await prepareModel()
        return try await generate(
            text: text,
            systemPrompt: RewritePromptBuilder.systemPrompt,
            makeUserPrompt: { protectedSource in
                RewritePromptBuilder.userPrompt(
                    text: protectedSource.text,
                    intensity: intensity,
                    protectedTokens: protectedSource.placeholderTokens
                )
            },
        )
    }

    private func generate(
        text: String,
        systemPrompt: String,
        makeUserPrompt: (ProtectedSource) -> String
    ) async throws -> String {
        guard let modelContainer else {
            throw RewriteError.modelUnavailable
        }

        releaseTask?.cancel()
        let protectedSource = SourceInstructionProtector.protect(text)

        let input = UserInput(
            chat: [
                .system(systemPrompt),
                .user(makeUserPrompt(protectedSource))
            ],
            additionalContext: ["enable_thinking": false]
        )

        await acquireGenerationSlot()
        defer { releaseGenerationSlot() }

        do {
            try Task.checkCancellation()
            let preparedInput = try await modelContainer.prepare(input: input)
            let parameters = GenerateParameters(
                maxTokens: RewritePromptBuilder.maximumOutputTokens(for: text),
                kvBits: 8,
                temperature: 0,
                repetitionPenalty: 1.03,
                repetitionContextSize: 64,
                prefillStepSize: 512
            )
            let stream = try await modelContainer.generate(
                input: preparedInput,
                parameters: parameters
            )

            var output = ""
            for await event in stream {
                try Task.checkCancellation()
                if case .chunk(let chunk) = event {
                    output.append(chunk)
                }
            }

            scheduleRelease()
            Memory.clearCache()
            let restored = protectedSource.restoringProtectedContent(in: output)
                ?? text
            let sanitized = try OutputSanitizer.sanitize(restored)
            let withoutFraming = OutputStyleGuard.removingIntroducedFraming(
                from: sanitized,
                source: text
            )
            return OutputStyleGuard.replacingOfficeFiller(
                in: withoutFraming,
                source: text
            )
        } catch is CancellationError {
            scheduleRelease()
            Memory.clearCache()
            throw RewriteError.cancelled
        } catch let error as RewriteError {
            scheduleRelease()
            Memory.clearCache()
            throw error
        } catch {
            scheduleRelease()
            Memory.clearCache()
            throw RewriteError.generationFailed
        }
    }

    private func scheduleRelease() {
        releaseTask?.cancel()
        guard !AppConstants.keepsModelResident else {
            releaseTask = nil
            return
        }

        operationID = UUID()
        let expectedID = operationID

        releaseTask = Task { [weak self] in
            do {
                try await Task.sleep(for: AppConstants.modelIdleLifetime)
                await self?.releaseIfIdle(expectedID: expectedID)
            } catch {
                // A new request superseded this release timer.
            }
        }
    }

    private func releaseIfIdle(expectedID: UUID) {
        guard expectedID == operationID else { return }
        modelPreparationTask?.cancel()
        modelPreparationTask = nil
        modelContainer = nil
        isWarmedUp = false
        Memory.clearCache()
    }

    private func acquireGenerationSlot() async {
        if !isGenerationActive {
            isGenerationActive = true
            return
        }

        await withCheckedContinuation { continuation in
            generationWaiters.append(continuation)
        }
    }

    private func releaseGenerationSlot() {
        guard !generationWaiters.isEmpty else {
            isGenerationActive = false
            return
        }

        generationWaiters.removeFirst().resume()
    }
}
