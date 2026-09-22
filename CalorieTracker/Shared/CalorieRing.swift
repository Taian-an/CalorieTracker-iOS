import SwiftUI

/// Ring showing eaten/goal calories. `progress` is eaten/goal clamped to [0,1] for the arc;
/// the color signals whether the goal was exceeded.
///
/// The arc sweeps in from zero when the screen appears and springs to each new value, and the
/// center number rolls (numeric content transition) instead of jumping.
struct CalorieRing: View {
    let eaten: Double
    let goal: Double
    var lineWidth: CGFloat = 14

    @State private var appeared = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(eaten / goal, 1)
    }

    private var isOver: Bool { goal > 0 && eaten > goal }
    private var remaining: Double { max(goal - eaten, 0) }

    private var arcGradient: AngularGradient {
        let colors: [Color] = isOver ? [Theme.danger.opacity(0.7), Theme.danger] : [Theme.calorie.opacity(0.55), Theme.calorie]
        return AngularGradient(colors: colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.calorie.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: appeared ? progress : 0)
                .stroke(arcGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: (isOver ? Theme.danger : Theme.calorie).opacity(0.35), radius: 6)

            VStack(spacing: 2) {
                Text(Int(appeared ? remaining : goal), format: .number)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: remaining))
                Text(String(Int(eaten)) + " / " + String(Int(goal)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: eaten))
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: progress)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: appeared)
        .onAppear { appeared = true }
    }
}

#Preview {
    CalorieRing(eaten: 1400, goal: 2000)
        .frame(width: 180, height: 180)
        .padding()
}
