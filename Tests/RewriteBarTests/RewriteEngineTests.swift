import RewriteCore
import Testing
@testable import RewriteBar

@Test
func requestNormalizesUserControlledValues() {
    let request = RewriteRequest(
        text: "Source",
        intensity: 42,
        writingStyle: .clear,
        customInstructions: "  Keep it direct.\0  ",
        customInstructionsExclusive: true
    )

    #expect(request.intensity == 10)
    #expect(request.writingStyle == .clear)
    #expect(request.customInstructions == "Keep it direct.")
    #expect(request.customInstructionsExclusive)

    let requestWithoutInstructions = RewriteRequest(
        text: "Source",
        intensity: 3,
        customInstructionsExclusive: true
    )
    #expect(!requestWithoutInstructions.customInstructionsExclusive)
}

@Test
func exclusiveCustomInstructionsReplaceTheSelectedWritingStyle() {
    let additivePrompt = RewritePromptBuilder.userPrompt(
        text: "Please review this.",
        intensity: 3,
        writingStyle: .persuasive,
        customInstructions: "Keep it understated."
    )
    #expect(additivePrompt.contains("Writing style: Persuasive"))
    #expect(additivePrompt.contains("Custom preference mode: additive"))

    let exclusivePrompt = RewritePromptBuilder.userPrompt(
        text: "Please review this.",
        intensity: 3,
        writingStyle: .persuasive,
        customInstructions: "Keep it understated.",
        customInstructionsExclusive: true
    )
    #expect(exclusivePrompt.contains("Writing style: Custom instructions only"))
    #expect(exclusivePrompt.contains("Custom preference mode: exclusive"))
    #expect(!exclusivePrompt.contains("Writing style: Persuasive"))
    #expect(!exclusivePrompt.contains(RewriteStyle.persuasive.promptInstruction))
}

@Test
func noContractionsPreferenceIsAppliedDeterministically() {
    let output = RewriteCustomInstructionsPolicy.applyingPresentation(
        to: "I'm ready. She’s finished. I'd rather wait. She said, \"I'm waiting.\"",
        source: "I am ready. She has finished. I would rather wait. She said, \"I'm waiting.\"",
        instructions: "Do not use contractions."
    )

    #expect(
        output
            == "I am ready. She has finished. I would rather wait. She said, \"I'm waiting.\""
    )

    let germanOutput = RewriteCustomInstructionsPolicy.applyingPresentation(
        to: "Wir arbeiten im Büro. Das ist gut.",
        source: "Wir arbeiten im Büro. Das ist gut.",
        instructions: "Do not use contractions."
    )
    #expect(germanOutput == "Wir arbeiten im Büro. Das ist gut.")
}

@Test
func personalizedOutputRetriesWhenAnyObviousMechanicalErrorRemains() {
    #expect(
        RewriteOutputQualityPolicy.needsUnpersonalizedRetry(
            source: "hey i didnt reply and itll be late",
            output: "Hey I didnt reply, but it will be late.",
            intensity: 3,
            customInstructions: "Keep it direct."
        )
    )
    #expect(
        !RewriteOutputQualityPolicy.needsUnpersonalizedRetry(
            source: "Wir arbeiten im Büro.",
            output: "Wir arbeiten im Büro.",
            intensity: 3,
            customInstructions: "Schreibe klar."
        )
    )
}

@Test
func engineReturnsGeneratorOutput() async throws {
    let generator = GeneratorStub(output: "Rewritten")
    let engine = RewriteEngine(
        generator: generator,
        timeoutSeconds: { _ in 1 }
    )

    let output = try await engine.rewrite(
        RewriteRequest(text: "Source", intensity: 3)
    )

    #expect(output == "Rewritten")
    #expect(await generator.requestCount == 1)
}

@Test
func engineTimesOutAndCancelsSlowGeneration() async throws {
    let generator = GeneratorStub(
        output: "Late",
        delay: .seconds(1)
    )
    let engine = RewriteEngine(
        generator: generator,
        timeoutSeconds: { _ in 0.02 }
    )

    do {
        _ = try await engine.rewrite(
            RewriteRequest(text: "Source", intensity: 3)
        )
        Issue.record("A slow generation did not time out.")
    } catch let error as RewriteError {
        #expect(error == .timedOut)
    }
}

private actor GeneratorStub: RewriteGenerating {
    private(set) var requestCount = 0
    private let output: String
    private let delay: Duration?

    init(
        output: String,
        delay: Duration? = nil
    ) {
        self.output = output
        self.delay = delay
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        requestCount += 1
        if let delay {
            try await Task.sleep(for: delay)
        }
        return output
    }
}
