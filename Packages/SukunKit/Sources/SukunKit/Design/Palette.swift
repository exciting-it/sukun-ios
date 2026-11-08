#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// A color that resolves differently in light and dark appearance (works in widgets too).
    static func dynamic(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark, alpha: darkAlpha) : UIColor(rgb: light, alpha: lightAlpha)
        })
        #else
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(rgb: dark, alpha: darkAlpha) : NSColor(rgb: light, alpha: lightAlpha)
        })
        #endif
    }

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32, alpha: Double) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}
#else
extension NSColor {
    convenience init(rgb: UInt32, alpha: Double) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}
#endif

/// Sukun's calm palette. Light: warm sand, deep green, slate. Dark: night blue, soft green, soft white.
/// Green is the single accent in both appearances.
public enum Palette {
    public static let background = Color.dynamic(light: 0xF6F1EA, dark: 0x0F1B2A)
    /// Card surface, slightly lifted from the background.
    public static let surface = Color.dynamic(light: 0xFFFCF7, dark: 0x16263A, lightAlpha: 0.85, darkAlpha: 0.85)
    /// Accent for fills, rings and indicators.
    public static let accent = Color.dynamic(light: 0x4E8A6A, dark: 0x6FAE8C)
    /// Accent for text and small symbols (WCAG AA ≥ 4.5:1 on background, cards and highlight).
    public static let accentText = Color.dynamic(light: 0x2F6B4F, dark: 0x8CC3A5)
    public static let text = Color.dynamic(light: 0x2E3A40, dark: 0xF3F0EA)
    public static let secondaryText = Color.dynamic(light: 0x5F6B70, dark: 0xA7B1BD)
    public static let divider = Color.dynamic(light: 0x2E3A40, dark: 0xF3F0EA, lightAlpha: 0.09, darkAlpha: 0.10)
    /// Soft green wash behind the current prayer.
    public static let highlight = Color.dynamic(light: 0x2F6B4F, dark: 0x5FA582, lightAlpha: 0.12, darkAlpha: 0.22)
    public static let shadow = Color.dynamic(light: 0x2E3A40, dark: 0x000000, lightAlpha: 0.06, darkAlpha: 0.0)

    public static let cornerRadius: CGFloat = 24
}
#endif
