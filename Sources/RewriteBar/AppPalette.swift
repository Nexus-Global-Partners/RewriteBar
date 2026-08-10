import SwiftUI

enum AppPalette {
    static let accent = Color(white: 0.40)
    static let frost = Color(white: 0.99)
    static let silver = Color(white: 0.88)
    static let steel = Color(white: 0.70)
    static let graphite = Color(white: 0.27)
    static let deepGraphite = Color(white: 0.14)

    // This semantic color follows the window's effective macOS appearance,
    // even while an already open Settings window changes appearance.
    static let settingsEnabledText = Color(nsColor: .labelColor).opacity(0.82)

    static func settingsPrimaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.78)
            : deepGraphite
    }

    static func settingsControlText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.72)
            : deepGraphite
    }

    static func settingsSeparator(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.10)
            : graphite.opacity(0.09)
    }
}
