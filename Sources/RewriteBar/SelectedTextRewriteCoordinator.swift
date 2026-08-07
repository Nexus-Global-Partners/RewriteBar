import Combine
import Foundation
import RewriteCore

@MainActor
final class SelectedTextRewriteCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case rewriting
        case replaced
        case failed(AccessibilityRewriteFailure)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var completedOutput: String?

    var onCompletion: (@MainActor (String) -> Void)?
    var onCopyOnlyCompletion: (@MainActor (String, AccessibilityRewriteFailure) -> Void)?
    var onFailure: (@MainActor (AccessibilityRewriteFailure) -> Void)?

    private let selectionProvider: any EditableTextSelectionProviding
    private let modelService: LocalModelService
    private var rewriteTask: Task<Void, Never>?
    private var activeRewriteID: UUID?

    init(
        selectionProvider: any EditableTextSelectionProviding = AccessibilitySelectionClient(),
        modelService: LocalModelService = .shared
    ) {
        self.selectionProvider = selectionProvider
        self.modelService = modelService
    }

    var isRewriting: Bool {
        state == .rewriting
    }

    func requestPermission() -> Bool {
        AccessibilityPermission.requestIfNeeded()
    }

    func startRewrite(
        intensity: Int,
        writingStyle: RewriteStyle = .rewriteBar,
        customInstructions: String? = nil,
        promptingForPermission: Bool = false
    ) {
        guard rewriteTask == nil else {
            showFailure(.rewriteAlreadyRunning)
            return
        }

        completedOutput = nil

        let snapshot: any EditableTextSelection
        do {
            snapshot = try selectionProvider.captureSelection(
                promptingForPermission: promptingForPermission
            )
            _ = try InputValidator.validate(
                plainText: snapshot.originalText,
                clipboardContainsItems: true
            )
        } catch let failure as AccessibilityRewriteFailure {
            showFailure(failure)
            return
        } catch let error as RewriteError {
            showFailure(.rewriteFailed(error))
            return
        } catch {
            showFailure(.rewriteFailed(.generationFailed))
            return
        }

        let safeIntensity = min(10, max(0, intensity))
        let rewriteID = UUID()
        activeRewriteID = rewriteID
        state = .rewriting
        rewriteTask = Task(priority: .userInitiated) { [weak self, modelService] in
            guard let self else { return }
            defer { finishRewrite(rewriteID) }

            do {
                let output = try await rewrite(
                    snapshot.originalText,
                    intensity: safeIntensity,
                    writingStyle: writingStyle,
                    customInstructions: customInstructions,
                    using: modelService
                )
                try Task.checkCancellation()
                guard activeRewriteID == rewriteID else { return }
                completedOutput = output
                do {
                    try snapshot.replaceSelection(with: output)
                    state = .replaced
                    onCompletion?(output)
                } catch let failure as AccessibilityRewriteFailure {
                    state = .failed(failure)
                    onCopyOnlyCompletion?(output, failure)
                }
            } catch is CancellationError {
                guard activeRewriteID == rewriteID else { return }
                state = .idle
            } catch let failure as AccessibilityRewriteFailure {
                guard activeRewriteID == rewriteID else { return }
                showFailure(failure)
            } catch let error as RewriteError {
                guard activeRewriteID == rewriteID else { return }
                showFailure(.rewriteFailed(error))
            } catch {
                guard activeRewriteID == rewriteID else { return }
                showFailure(.rewriteFailed(.generationFailed))
            }
        }
    }

    func cancel() {
        rewriteTask?.cancel()
        rewriteTask = nil
        activeRewriteID = nil
        completedOutput = nil
        state = .idle
    }

    func resetState() {
        guard rewriteTask == nil else { return }
        completedOutput = nil
        state = .idle
    }

    private func rewrite(
        _ text: String,
        intensity: Int,
        writingStyle: RewriteStyle,
        customInstructions: String?,
        using modelService: LocalModelService
    ) async throws -> String {
        let timeout = PreparationPolicy.timeoutSeconds(
            forCharacterCount: text.count
        )

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await modelService.rewrite(
                    text: text,
                    intensity: intensity,
                    writingStyle: writingStyle,
                    customInstructions: customInstructions
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

    private func showFailure(_ failure: AccessibilityRewriteFailure) {
        completedOutput = nil
        state = .failed(failure)
        onFailure?(failure)
    }

    private func finishRewrite(_ rewriteID: UUID) {
        guard activeRewriteID == rewriteID else { return }
        rewriteTask = nil
        activeRewriteID = nil
    }
}
