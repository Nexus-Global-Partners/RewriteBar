import RewriteCore
import Testing

@Test
func fidelityValidatorAcceptsDashFreeFactFormatting() {
    let source = "Latency in eu-west-1 rose from 180 ms to 640 ms at 09:10."
    let output = "At 09:10, latency in eu west 1 rose from 180 ms to 640 ms."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(report.preservesCriticalFacts)
}

@Test
func fidelityValidatorFindsMissingNumbersAndQuotes() {
    let source = "Revenue grew 6.2% in Q2. Keep “Your plan will not change.”"
    let output = "Revenue grew in Q2. Your plan may change."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(report.missingFacts.contains("6.2%"))
    #expect(report.missingQuotedPassages == ["“Your plan will not change.”"])
    #expect(!report.preservesCriticalFacts)
}

@Test
func fidelityValidatorFindsChangedCommitments() {
    let source = "We can refund €84.50 if needed."
    let output = "We will refund €84.50 if needed."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(report.changedModality.contains("can"))
    #expect(report.changedModality.contains("will"))
    #expect(report.strengthenedCommitment)
    #expect(!report.preservesMeaningSignals)
}

@Test
func fidelityValidatorAllowsAHarmlessTenseModal() {
    let source = "We can refund it. Delivery takes 3 days."
    let output = "We can refund it. Delivery will take 3 days."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(!report.changedModality.isEmpty)
    #expect(!report.strengthenedCommitment)
    #expect(report.preservesMeaningSignals)
}

@Test
func fidelityValidatorDoesNotMatchUnrelatedModalVerbs() {
    let source = "We can say the interface is faster. The rollout expands only after review."
    let output = "Say the interface is faster. The rollout will expand only after review."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(!report.strengthenedCommitment)
    #expect(report.preservesMeaningSignals)
}

@Test
func promptLocksTheSourceModalProfile() {
    let prompt = RewritePromptBuilder.userPrompt(
        text: "We can send another one, or we can refund it.",
        intensity: 8
    )

    #expect(prompt.contains("can × 2"))
    #expect(prompt.contains("introduce no other modal"))
}

@Test
func fidelityValidatorRejectsInventedCausality() {
    let source = "The permissions screen is confusing. Support got 18 questions."
    let output = "The permissions screen caused 18 questions from support."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(report.introducedCausality == ["strong causal link"])
    #expect(!report.preservesMeaningSignals)
}

@Test
func fidelityValidatorAllowsExistingCausalityToBeRephrased() {
    let source = "The delay happened because review was late."
    let output = "The delay was due to the late review."

    let report = OutputFidelityValidator.evaluate(source: source, output: output)

    #expect(report.introducedCausality.isEmpty)
}
