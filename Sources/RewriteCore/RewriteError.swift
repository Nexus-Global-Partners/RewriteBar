import Foundation

public enum RewriteError: LocalizedError, Equatable, Sendable {
    case noText
    case unsupportedClipboard
    case textTooLong(maximum: Int)
    case modelUnavailable
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
            "The copied text is over the \(maximum.formatted()) character limit."
        case .modelUnavailable:
            "The local model is not installed."
        case .modelLoadFailed:
            "The local model could not be loaded."
        case .generationFailed:
            "The rewrite could not be completed."
        case .timedOut:
            "The local model took too long to respond."
        case .emptyOutput:
            "The model returned no rewritten text."
        case .cancelled:
            "The rewrite was cancelled."
        }
    }
}
