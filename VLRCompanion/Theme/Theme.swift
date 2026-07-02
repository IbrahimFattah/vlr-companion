import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    /// Dynamic color that adapts to the current light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// True when a hex color is bright enough to need dark foreground text.
    static func hexIsLight(_ hex: String) -> Bool {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6
    }
}

/// Design tokens. Deep desaturated navy-charcoal surfaces; red is reserved
/// exclusively for LIVE states so it always means "happening right now".
enum Theme {
    static let background = Color(light: Color(hex: "F2F3F7"), dark: Color(hex: "0E1116"))
    static let surface = Color(light: .white, dark: Color(hex: "161B22"))
    static let elevated = Color(light: Color(hex: "E9EBF0"), dark: Color(hex: "1D242E"))

    /// Live-state red. Never used as decoration.
    static let live = Color(hex: "FF4655")
    static let win = Color(hex: "30D158")
    static let loss = Color(hex: "FF6369")

    /// Monochrome interactive accent — typography-forward, lets team colors
    /// and the live red carry all the chroma.
    static let accent = Color(light: Color(hex: "14181D"), dark: Color(hex: "E6ECF2"))

    static let cardCornerRadius: CGFloat = 16
}

enum Appearance: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

extension View {
    /// Standard card treatment used by every match/event/stat row.
    func cardBackground() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}
