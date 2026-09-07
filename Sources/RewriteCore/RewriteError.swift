import Foundation

public enum RewriteError: LocalizedError, Equatable, Sendable {
    case noText
    case unsupportedClipboard
    case textTooLong(maximum: Int)
    case modelUnavailable
    case accountRequired
    case runtimeRequired
    case usageLimitReached
    case connectionFailed
    case modelLoadFailed
    case generationFailed
    case timedOut
    case emptyOutput
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noText:
            "Copy some text first."
        case .unsupportedClipboard:
            "The clipboard does not contain plain text."
        case .textTooLong(let maximum):
            "The selected text is over the \(maximum.formatted()) character limit."
        case .modelUnavailable:
            "The rewrite model is unavailable on your Codex account."
        case .accountRequired:
            "Connect your ChatGPT account in RewriteBar Settings."
        case .runtimeRequired:
            "Install or update the official Codex app, then try again."
        case .usageLimitReached:
            "Your Codex usage limit has been reached. Try again after it resets."
        case .connectionFailed:
            "Codex could not be reached. Check your connection and try again."
        case .modelLoadFailed:
            "The local model could not be loaded."
        case .generationFailed:
            "The rewrite could not be completed."
        case .timedOut:
            "The rewrite took too long to respond."
        case .emptyOutput:
            "The model returned no rewritten text."
        case .cancelled:
            "The rewrite was cancelled."
        }
    }
}
