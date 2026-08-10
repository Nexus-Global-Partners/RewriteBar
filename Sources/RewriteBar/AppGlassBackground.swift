import AppKit
import SwiftUI

struct AppGlassBackground: View {
    var neutralSurfaceOpacity: Double = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            if neutralSurfaceOpacity > 0 {
                Rectangle()
                    .fill(neutralSurface)
            }

            RadialGradient(
                colors: [
                    .white.opacity(highlightOpacity),
                    AppPalette.silver.opacity(silverOpacity),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 250
            )

            LinearGradient(
                colors: [
                    AppPalette.frost.opacity(frostOpacity),
                    AppPalette.graphite.opacity(graphiteOpacity),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.white.opacity(topGlowOpacity), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(topEdgeOpacity))
                .frame(height: 1)
        }
        .ignoresSafeArea()
    }

    private var usesNeutralSettingsSurface: Bool {
        neutralSurfaceOpacity > 0
    }

    private var neutralSurface: Color {
        if colorScheme == .dark {
            return .black.opacity(0.66)
        }

        return Color(nsColor: .windowBackgroundColor)
            .opacity(neutralSurfaceOpacity)
    }

    private var highlightOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.075 : 0.20
    }

    private var silverOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.035 : 0.10
    }

    private var frostOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.025 : 0.08
    }

    private var graphiteOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.08 : 0.05
    }

    private var topGlowOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.06 : 0.15
    }

    private var topEdgeOpacity: Double {
        colorScheme == .dark && usesNeutralSettingsSurface ? 0.13 : 0.24
    }
}
