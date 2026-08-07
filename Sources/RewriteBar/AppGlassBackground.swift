import AppKit
import SwiftUI

struct AppGlassBackground: View {
    var neutralSurfaceOpacity: Double = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            if neutralSurfaceOpacity > 0 {
                Rectangle()
                    .fill(
                        Color(nsColor: .windowBackgroundColor)
                            .opacity(neutralSurfaceOpacity)
                    )
            }

            RadialGradient(
                colors: [
                    .white.opacity(0.20),
                    AppPalette.silver.opacity(0.10),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 250
            )

            LinearGradient(
                colors: [
                    AppPalette.frost.opacity(0.08),
                    AppPalette.graphite.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.white.opacity(0.15), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.24))
                .frame(height: 1)
        }
        .ignoresSafeArea()
    }
}
