import SwiftUI

/// Small reusable motion pieces so every screen gets the same feel.

/// Cards and rows shrink slightly while pressed and spring back — tactile feedback for tappable cards.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Sweeping highlight over `.redacted(reason: .placeholder)` skeletons while content loads.
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.45), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width * 1.6)
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// List items slide up and fade in one after another instead of popping in all at once.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(min(index, 10)) * 0.04)) {
                    visible = true
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
    func staggeredAppear(index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
}
