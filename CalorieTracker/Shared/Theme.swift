import SwiftUI

enum Theme {
    static let calorie = Color.orange
    static let protein = Color.pink
    static let carbs = Color.yellow
    static let fat = Color.purple
    static let success = Color.green
    static let danger = Color.red

    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)

    static let cardCornerRadius: CGFloat = 16
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}
