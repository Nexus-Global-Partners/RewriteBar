import Combine
import Foundation
import RewriteCore

@MainActor
final class RewriteViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case rewriting
        case ready
        case copied
        case failed(RewriteError)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var canRestorePreviousClipboard = false
    @Published private(set) var rewriteProgress = 0.0
    @Published var intensity: Double {
        didSet {
            let oldLevel = Int(oldValue.rounded())
            let newLevel = Int(intensity.rounded())
            UserDefaults.standard.set(newLevel, forKey: Self.intensityKey)

            if oldLevel != newLevel, state == .ready {
                preparedOutput = nil
                sourceText = nil
                state = .idle
            }
        }
    }

    private static let intensityKey = "rewriteIntensity"
    private static let defaultIntensity = 3

    private let clipboard = ClipboardService()
    private let modelService: LocalModelService
    private var sourceText: String?
    private var preparedOutput: String?
    private var previousClipboardText: String?
    private var copiedRewriteText: String?
    private var generationTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var copiedConfirmationTask: Task<Void, Never>?
    private var generationID = UUID()
    private var isPopoverVisible = false

    init(modelService: LocalModelService = .shared) {
        self.modelService = modelService
        let stored = UserDefaults.standard.object(forKey: Self.intensityKey) as? Int
            ?? Self.defaultIntensity
        intensity = Double(min(10, max(0, stored)))
    }

    var title: String {
        switch state {
        case .idle:
            return "Rewrite"
        case .rewriting:
            return "Rewriting · Cancel"
        case .ready:
            return "Copy Rewrite"
        case .copied:
            return "Copied"
        case .failed(let error):
            return errorButtonTitle(for: error)
        }
    }

    var symbol: String {
        switch state {
        case .idle, .ready:
            return "infinity"
        case .rewriting:
            return "circle.dotted"
        case .copied:
            return "checkmark"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var isWorking: Bool {
        state == .rewriting
    }

    var isEnabled: Bool {
        switch state {
        case .idle, .rewriting, .ready:
            return true
        case .copied:
            return false
        case .failed(let error):
            return errorAllowsRetry(error)
        }
    }

    var isConfirmation: Bool {
        state == .copied
    }

    var accessibilityHint: String {
        switch state {
        case .idle:
            return "Rewrites the plain text currently on the clipboard."
        case .rewriting:
            return "Cancels the current rewrite."
        case .ready:
            return "Copies the finished rewrite to the clipboard."
        case .copied:
            return "The rewrite was copied to the clipboard."
        case .failed:
            return isEnabled
                ? "Tries the rewrite again using the current clipboard text."
                : "Copy plain text, then reopen RewriteBar."
        }
    }

    func popoverOpened() {
        isPopoverVisible = true
        validateClipboardHistory()

        if case .failed = state {
            state = .idle
        }
    }

    func popoverClosed() {
        isPopoverVisible = false

        if state == .copied {
            copiedConfirmationTask?.cancel()
            copiedConfirmationTask = nil
            state = .idle
        }
    }

    @discardableResult
    func restorePreviousClipboard() -> Bool {
        guard canRestorePreviousClipboard,
              let previousClipboardText else {
            return false
        }

        generationTask?.cancel()
        progressTask?.cancel()
        progressTask = nil
        copiedConfirmationTask?.cancel()
        copiedConfirmationTask = nil
        clipboard.writePlainText(previousClipboardText)
        clearClipboardHistory()
        sourceText = nil
        preparedOutput = nil
        state = .idle
        return true
    }

    @discardableResult
    func perform() -> Bool {
        switch state {
        case .idle:
            startRewrite()
            return false
        case .rewriting:
            cancelRewrite()
            return false
        case .ready:
            return copyPreparedResult()
        case .copied:
            return false
        case .failed(let error) where errorAllowsRetry(error):
            startRewrite()
            return false
        case .failed:
            return false
        }
    }

    private func startRewrite() {
        let text: String
        do {
            text = try clipboard.readPlainText()
        } catch let error as RewriteError {
            showFailure(error)
            return
        } catch {
            showFailure(.unsupportedClipboard)
            return
        }

        generationTask?.cancel()
        progressTask?.cancel()
        copiedConfirmationTask?.cancel()
        copiedConfirmationTask = nil
        let requestID = UUID()
        generationID = requestID
        let rewriteIntensity = Int(intensity.rounded())

        sourceText = text
        preparedOutput = nil
        rewriteProgress = 0
        state = .rewriting
        startProgressAnimation()

        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Rewrite clipboard text"
        )

        generationTask = Task(priority: .userInitiated) { [weak self, modelService] in
            defer {
                ProcessInfo.processInfo.endActivity(activity)
            }
            guard let self else { return }

            do {
                let output = try await rewrite(
                    text: text,
                    intensity: rewriteIntensity,
                    modelService: modelService
                )
                try Task.checkCancellation()
                guard requestID == generationID else { return }

                progressTask?.cancel()
                progressTask = nil
                preparedOutput = output
                if isPopoverVisible {
                    rewriteProgress = 1
                    try await Task.sleep(for: .milliseconds(180))
                    try Task.checkCancellation()
                    guard requestID == generationID else { return }
                    if isPopoverVisible {
                        _ = copyPreparedResult(showConfirmation: true)
                    } else {
                        rewriteProgress = 0
                        state = .ready
                    }
                } else {
                    rewriteProgress = 0
                    state = .ready
                }
            } catch is CancellationError {
                return
            } catch let error as RewriteError {
                guard error != .cancelled, requestID == generationID else { return }
                showFailure(error)
            } catch {
                guard requestID == generationID else { return }
                showFailure(.generationFailed)
            }

            if requestID == generationID {
                generationTask = nil
            }
        }
    }

    private func rewrite(
        text: String,
        intensity: Int,
        modelService: LocalModelService
    ) async throws -> String {
        let timeout = PreparationPolicy.timeoutSeconds(
            forCharacterCount: text.count
        )

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await modelService.rewrite(
                    text: text,
                    intensity: intensity
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

    private func cancelRewrite() {
        generationTask?.cancel()
        generationTask = nil
        progressTask?.cancel()
        progressTask = nil
        copiedConfirmationTask?.cancel()
        copiedConfirmationTask = nil
        generationID = UUID()
        sourceText = nil
        preparedOutput = nil
        rewriteProgress = 0
        state = .idle
    }

    private func startProgressAnimation() {
        progressTask?.cancel()
        let startedAt = Date()

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, let self, state == .rewriting else { return }

                let elapsed = Date().timeIntervalSince(startedAt)
                rewriteProgress = min(0.96, 1 - exp(-elapsed / 2.2))
            }
        }
    }

    private func copyPreparedResult(showConfirmation: Bool = false) -> Bool {
        guard let preparedOutput,
              let sourceText else {
            showFailure(.emptyOutput)
            return false
        }

        previousClipboardText = sourceText
        copiedRewriteText = preparedOutput
        canRestorePreviousClipboard = true
        clipboard.writePlainText(preparedOutput)
        self.sourceText = nil
        self.preparedOutput = nil
        rewriteProgress = 0

        if showConfirmation {
            state = .copied
            scheduleCopiedReset()
        } else {
            state = .idle
        }
        return true
    }

    private func scheduleCopiedReset() {
        copiedConfirmationTask?.cancel()
        copiedConfirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled, let self else { return }
            if state == .copied {
                state = .idle
            }
            copiedConfirmationTask = nil
        }
    }

    private func validateClipboardHistory() {
        guard canRestorePreviousClipboard,
              let copiedRewriteText else {
            return
        }

        do {
            if try clipboard.readPlainText() != copiedRewriteText {
                clearClipboardHistory()
            }
        } catch {
            clearClipboardHistory()
        }
    }

    private func clearClipboardHistory() {
        previousClipboardText = nil
        copiedRewriteText = nil
        canRestorePreviousClipboard = false
    }

    private func showFailure(_ error: RewriteError) {
        progressTask?.cancel()
        progressTask = nil
        copiedConfirmationTask?.cancel()
        copiedConfirmationTask = nil
        preparedOutput = nil
        sourceText = nil
        rewriteProgress = 0
        state = .failed(error)
    }

    private func errorAllowsRetry(_ error: RewriteError) -> Bool {
        switch error {
        case .modelLoadFailed, .generationFailed, .timedOut, .emptyOutput:
            return true
        case .noText, .unsupportedClipboard, .textTooLong, .modelUnavailable, .cancelled:
            return false
        }
    }

    private func errorButtonTitle(for error: RewriteError) -> String {
        switch error {
        case .noText:
            return "Copy Text First"
        case .unsupportedClipboard:
            return "Plain Text Only"
        case .textTooLong:
            return "Text Is Too Long"
        case .modelUnavailable:
            return "App Is Incomplete"
        case .modelLoadFailed:
            return "Model Failed · Retry"
        case .generationFailed, .emptyOutput:
            return "Failed · Retry"
        case .timedOut:
            return "Took Too Long · Retry"
        case .cancelled:
            return "Rewrite"
        }
    }
}
