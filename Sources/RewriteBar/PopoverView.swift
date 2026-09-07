import SwiftUI

struct PopoverView: View {
    @ObservedObject var settings: RewriteSettingsStore
    var close: () -> Void = {}
    var openSettings: () -> Void = {}

    var body: some View {
        GlassyIntensitySlider(
            value: Binding(
                get: { Double(settings.activeIntensity) },
                set: { settings.selectIntensity(Int($0.rounded())) }
            ),
            onCommit: close
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 252, height: 60)
        .background { AppGlassBackground() }
        .onKeyPress(.return) { close(); return .handled }
        .onKeyPress(.escape) { close(); return .handled }
        .contextMenu {
            Button("Use default (\(settings.defaultIntensity))") {
                settings.resetIntensity()
                close()
            }
            Button("Settings…", action: openSettings)
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
