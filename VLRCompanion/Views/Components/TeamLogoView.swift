import SwiftUI

/// Team crest. Real logo art isn't available from the sample data, so this
/// renders a brand-color monogram; when the API is wired in and `logoURL` is
/// populated, it upgrades to the real image automatically.
struct TeamLogoView: View {
    let team: Team
    var size: CGFloat = 40

    private var color: Color { Color(hex: team.colorHex) }

    var body: some View {
        Group {
            if let url = team.logoURL {
                // Backing plate keeps black-on-transparent crests visible in dark mode.
                ZStack {
                    Circle().fill(Theme.elevated)
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        monogram
                    }
                    .padding(size * 0.12)
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
    }

    private var monogram: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [color, color.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(team.tag.prefix(3))
                .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.hexIsLight(team.colorHex) ? Color.black.opacity(0.8) : .white)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
        }
    }
}
