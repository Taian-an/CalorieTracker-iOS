import SwiftUI

struct MacroBar: View {
    let label: String
    let color: Color
    let current: Double
    let target: Double

    @State private var appeared = false

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(current))g / \(Int(target))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: current))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color.gradient)
                        .frame(width: geometry.size.width * (appeared ? progress : 0))
                }
            }
            .frame(height: 8)
        }
        // bars grow in from empty on first appearance, then spring to each new total
        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(appeared ? 0 : 0.15), value: appeared)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
        .onAppear { appeared = true }
    }
}

#Preview {
    VStack(spacing: 16) {
        MacroBar(label: "Protein", color: Theme.protein, current: 60, target: 100)
        MacroBar(label: "Carbs", color: Theme.carbs, current: 180, target: 250)
        MacroBar(label: "Fat", color: Theme.fat, current: 40, target: 67)
    }
    .padding()
}
