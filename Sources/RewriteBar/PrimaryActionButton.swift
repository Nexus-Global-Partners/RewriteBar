import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let symbol: String
    let isWorking: Bool
    let accessibilityHint: String
    var acceptsReturnKey = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Group {
            if acceptsReturnKey {
                button
                    .keyboardShortcut(.return, modifiers: [])
            } else {
                button
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isWorking {
                    LoadingIndicator()
                } else {
                    Image(systemName: symbol)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(isHovering ? 0.72 : 0.64))

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.88), lineWidth: 0.7)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.56), lineWidth: 2.5)
                        .blur(radius: 2)
                        .offset(x: -0.8, y: -0.8)
                        .mask {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                        }

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            AppPalette.graphite.opacity(isHovering ? 0.06 : 0.08),
                            lineWidth: 2.5
                        )
                        .blur(radius: 2)
                        .offset(x: 0.8, y: 0.8)
                        .mask {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                        }

                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(AppPalette.graphite.opacity(0.04), lineWidth: 0.7)
                        .padding(1.2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isHovering && !reduceMotion ? 1.003 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovering)
    }

    private var foregroundColor: Color {
        AppPalette.deepGraphite
    }
}

struct LoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0.14, to: 0.86)
            .stroke(
                AppPalette.deepGraphite,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
            .frame(width: 13, height: 13)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                reduceMotion
                    ? nil
                    : .linear(duration: 0.72).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = !reduceMotion
            }
    }
}
