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
    private let rewriteEngine: RewriteEngine
    private var rewriteTask: Task<Void, Never>?
    private var activeRewriteID: UUID?

    init(
        selectionProvider: any EditableTextSelectionProviding = AccessibilitySelectionClient(),
        rewriteEngine: RewriteEngine = .shared
    ) {
        self.selectionProvider = selectionProvider
        self.rewriteEngine = rewriteEngine
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
        customInstructionsExclusive: Bool = false,
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
        let request = RewriteRequest(
            text: snapshot.originalText,
            intensity: safeIntensity,
            writingStyle: writingStyle,
            customInstructions: customInstructions,
            customInstructionsExclusive: customInstructionsExclusive
        )
        rewriteTask = Task(priority: .userInitiated) { [weak self, rewriteEngine] in
            guard let self else { return }
            defer { finishRewrite(rewriteID) }

            do {
                let output = try await rewriteEngine.rewrite(request)
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
