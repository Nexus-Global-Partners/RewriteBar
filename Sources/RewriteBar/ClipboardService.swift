import AppKit
import RewriteCore

struct ClipboardService: Sendable {
    @MainActor
    func readPlainText() throws -> String {
        let pasteboard = NSPasteboard.general
        let normalizedText = pasteboard.string(forType: .string).map(
            ClipboardTextNormalizer.normalize
        )
        return try InputValidator.validate(
            plainText: normalizedText,
            clipboardContainsItems: !(pasteboard.pasteboardItems ?? []).isEmpty
        )
    }

    @MainActor
    func writePlainText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
