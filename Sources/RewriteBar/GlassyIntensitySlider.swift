import RewriteCore
import SwiftUI

/// One rail and one numbered thumb, with no surrounding control container.
struct GlassyIntensitySlider: View {
    @Binding var value: Double
    var onCommit: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    private let thumbSize: CGFloat = 28
    private let inset: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let travel = max(1, geometry.size.width - inset * 2)
            let progress = CGFloat(min(10, max(0, value)) / 10)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 3)
                    .padding(.horizontal, inset)
                Capsule()
                    .fill(Color.primary.opacity(0.42))
                    .frame(width: travel * progress, height: 3)
                    .offset(x: inset)
                ForEach(0..<11) { index in
                    Circle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 2, height: 2)
                        .offset(x: inset + travel * CGFloat(index) / 10 - 1)
                }
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black.opacity(0.80))
                    .frame(width: thumbSize, height: thumbSize)
                    .background {
                        Circle()
                            .fill(colorScheme == .dark ? Color(white: 0.30) : .white)
                            .shadow(color: .black.opacity(0.13), radius: 3, y: 1)
                    }
                    .overlay {
                        Circle().strokeBorder(
                            Color.primary.opacity(isFocused ? 0.40 : 0.07),
                            lineWidth: isFocused ? 1.5 : 0.5
                        )
                    }
                    .offset(x: inset + travel * progress - thumbSize / 2)
            }
            .frame(height: 36)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { update($0.location.x, travel: travel) }
                .onEnded {
                    update($0.location.x, travel: travel)
                    onCommit()
                }
            )
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(.leftArrow) { adjust(-1); return .handled }
            .onKeyPress(.rightArrow) { adjust(1); return .handled }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: value)
        }
        .frame(height: 36)
        .help(RewriteIntensityPolicy.definition(for: Int(value.rounded())))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rewrite intensity")
        .accessibilityValue("\(Int(value.rounded())) out of 10")
        .accessibilityHint("Arrow keys change the level. Return closes the slider. Right-click for Settings.")
        .accessibilityAdjustableAction {
            switch $0 {
            case .increment: adjust(1)
            case .decrement: adjust(-1)
            @unknown default: break
            }
        }
    }
    private func update(_ x: CGFloat, travel: CGFloat) {
        value = (Double(min(travel, max(0, x - inset)) / travel) * 10).rounded()
    }
    private func adjust(_ amount: Double) {
        value = min(10, max(0, value + amount))
    }
}
