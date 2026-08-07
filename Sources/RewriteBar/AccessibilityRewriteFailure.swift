import ApplicationServices
import Foundation
import RewriteCore

enum AccessibilityRewriteFailure: Error, Equatable, LocalizedError, Sendable {
    case permissionRequired
    case noFocusedApplication
    case noFocusedElement
    case secureField
    case selectionUnavailable
    case selectionEmpty
    case multipleSelectionsUnsupported
    case selectionNotEditable
    case focusChanged
    case selectionChanged
    case rewriteAlreadyRunning
    case invalidShortcut
    case shortcutConflict
    case shortcutRegistrationFailed(OSStatus)
    case accessibilityFailure(AXError)
    case rewriteFailed(RewriteError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Allow RewriteBar to control your Mac in Privacy & Security settings."
        case .noFocusedApplication:
            return "No active application was found."
        case .noFocusedElement:
            return "No editable text field is focused."
        case .secureField:
            return "RewriteBar never reads or changes secure text fields."
        case .selectionUnavailable:
            return "The active application does not expose its selected text."
        case .selectionEmpty:
            return "Select some text before using the rewrite shortcut."
        case .multipleSelectionsUnsupported:
            return "RewriteBar can replace one continuous text selection at a time."
        case .selectionNotEditable:
            return "The selected text cannot be replaced in this application."
        case .focusChanged:
            return "The active text field changed before the rewrite finished."
        case .selectionChanged:
            return "The selection changed before the rewrite finished."
        case .rewriteAlreadyRunning:
            return "A shortcut rewrite is already running."
        case .invalidShortcut:
            return "Choose a shortcut that includes Command, Control, or Option."
        case .shortcutConflict:
            return "That keyboard shortcut is already used by another application."
        case .shortcutRegistrationFailed(let status):
            return "The keyboard shortcut could not be registered. Error \(status)."
        case .accessibilityFailure(let error):
            return "macOS Accessibility returned error \(error.rawValue)."
        case .rewriteFailed(let error):
            return error.errorDescription ?? "The selected text could not be rewritten."
        }
    }
}
