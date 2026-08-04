import Foundation

public enum InputValidator {
    public static func validate(
        plainText: String?,
        clipboardContainsItems: Bool,
        maximumCharacters: Int = AppConstants.maximumInputCharacters
    ) throws -> String {
        guard let plainText else {
            throw clipboardContainsItems ? RewriteError.unsupportedClipboard : RewriteError.noText
        }

        guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RewriteError.noText
        }

        guard plainText.count <= maximumCharacters else {
            throw RewriteError.textTooLong(maximum: maximumCharacters)
        }

        return plainText
    }
}
