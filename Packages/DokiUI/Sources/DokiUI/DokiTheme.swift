import SwiftUI
import UIKit

public enum DokiTheme {
    public static let accent = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .light {
            return UIColor(red: 0.40, green: 0.27, blue: 0.68, alpha: 1)
        }
        return UIColor(red: 0.67, green: 0.54, blue: 0.94, alpha: 1)
    })
    public static let pagePadding: CGFloat = 48
    public static let sectionSpacing: CGFloat = 40
    public static let cardRadius: CGFloat = 16
    public static let heroRadius: CGFloat = 24
    public static let contentMaxWidth: CGFloat = 1_360

    public static func pageBackground(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.83, green: 0.85, blue: 0.89)
            : Color(red: 0.245, green: 0.265, blue: 0.35)
    }

    public static func controlSurface(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.88, green: 0.90, blue: 0.92)
            : Color(red: 0.10, green: 0.12, blue: 0.15)
    }

    public static func accent(hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .light {
                return UIColor(
                    red: red * 0.66,
                    green: green * 0.66,
                    blue: blue * 0.66,
                    alpha: 1
                )
            }
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        })
    }

    public static let fallbackGradients: [[Color]] = [
        [Color(red: 0.13, green: 0.50, blue: 0.47), Color(red: 0.04, green: 0.09, blue: 0.12)],
        [Color(red: 0.55, green: 0.28, blue: 0.22), Color(red: 0.09, green: 0.06, blue: 0.08)],
        [Color(red: 0.19, green: 0.32, blue: 0.53), Color(red: 0.04, green: 0.07, blue: 0.13)],
        [Color(red: 0.54, green: 0.43, blue: 0.16), Color(red: 0.10, green: 0.08, blue: 0.04)]
    ]

    public static func fallbackGradient(for title: String) -> [Color] {
        let index = title.unicodeScalars.reduce(0) { $0 + Int($1.value) } % fallbackGradients.count
        return fallbackGradients[index]
    }
}

public extension Color {
    init(dokiHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch cleaned.count {
        case 3:
            red = (value >> 8) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
        case 8:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        default:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

public enum DokiType {
    public static let pageTitle = Font.system(size: 58, weight: .bold, design: .default)
    public static let sectionTitle = Font.system(size: 30, weight: .semibold, design: .default)
    public static let cardTitle = Font.system(size: 23, weight: .semibold, design: .default)
    public static let body = Font.system(size: 23, weight: .regular, design: .default)
    public static let caption = Font.system(size: 20, weight: .medium, design: .default)
    public static let micro = Font.system(size: 16, weight: .medium, design: .default)
    public static let hero = Font.system(size: 68, weight: .bold, design: .default)
}


public struct DokiBackground: View {
    @Environment(\.dokiSharedBackground) private var sharedBackground
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if !sharedBackground {
            DokiTheme.pageBackground(for: colorScheme).ignoresSafeArea()
        }
    }
}

public extension EnvironmentValues {
    @Entry var dokiSharedBackground: Bool = false
    @Entry var dokiCardFocused: Bool = false
    var dokiReduceMotion: Bool {
        #if DEBUG
        accessibilityReduceMotion || ProcessInfo.processInfo.arguments.contains("--demo-reduce-motion")
        #else
        accessibilityReduceMotion
        #endif
    }
    var dokiReduceTransparency: Bool {
        #if DEBUG
        accessibilityReduceTransparency || ProcessInfo.processInfo.arguments.contains("--demo-reduce-transparency")
        #else
        accessibilityReduceTransparency
        #endif
    }
}
