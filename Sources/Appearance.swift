import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct PartyPalette {
    let background: Color
    let foreground: Color
    let muted: Color
    let accent: Color
    let highlight: Color

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            background = Color(red: 0.075, green: 0.071, blue: 0.067)
            foreground = Color(red: 0.97, green: 0.96, blue: 0.95)
            muted = Color(red: 0.58, green: 0.57, blue: 0.56)
            accent = Color(red: 1, green: 0.62, blue: 0.32)
            highlight = Color(red: 1, green: 0.80, blue: 0.57)
        } else {
            background = Color(red: 0.98, green: 0.96, blue: 0.93)
            foreground = Color(red: 0.13, green: 0.12, blue: 0.10)
            muted = Color(red: 0.43, green: 0.40, blue: 0.36)
            accent = Color(red: 0.72, green: 0.29, blue: 0.02)
            highlight = Color(red: 0.63, green: 0.30, blue: 0.10)
        }
    }
}
