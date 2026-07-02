import SwiftUI

/// Emoji-on-color chip used for account avatars everywhere.
struct AccountAvatar: View {
    let emoji: String
    let colorHex: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(Text(emoji).font(.system(size: size * 0.5)))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

enum AvatarChoices {
    static let emojis = ["🎯", "🦊", "🐉", "👑", "🔥", "⚡️", "🎮", "🛡️", "🏆", "💥", "🚀", "🧠"]
    static let colors = ["FF4655", "30D158", "5E5CE6", "FF9F0A", "64D2FF", "BF5AF2", "FF375F", "32D74B"]
}
