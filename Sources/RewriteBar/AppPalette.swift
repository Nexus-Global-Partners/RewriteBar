import SwiftUI

enum AppPalette {
    static let accent = Color(white: 0.40)
    static let frost = Color(white: 0.99)
    static let silver = Color(white: 0.88)
    static let steel = Color(white: 0.70)
    static let graphite = Color(white: 0.27)
    static let deepGraphite = Color(white: 0.14)

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
}
