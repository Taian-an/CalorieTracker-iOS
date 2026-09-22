import SwiftUI

/// Built-in avatar set, keyed the same way as calorie-app's `avatarKey` (default/a1/a2/a3).
/// Rendered as SF Symbol + color tiles rather than porting the RN app's stock photos.
enum BuiltInAvatar: String, CaseIterable, Identifiable {
    case `default`, a1, a2, a3
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .default: return "person.fill"
        case .a1: return "hare.fill"
        case .a2: return "tortoise.fill"
        case .a3: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .default: return .gray
        case .a1: return .orange
        case .a2: return .green
        case .a3: return .blue
        }
    }
}

struct AvatarView: View {
    var avatarKey: String?
    var size: CGFloat = 72

    private var avatar: BuiltInAvatar { avatarKey.flatMap(BuiltInAvatar.init(rawValue:)) ?? .default }

    var body: some View {
        Circle()
            .fill(avatar.color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: avatar.symbol)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            }
    }
}
