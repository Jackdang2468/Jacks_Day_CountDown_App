import SwiftUI

/// Gradient backgrounds used when a countdown has no photo.
enum CountdownTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case ocean, sunset, aurora, forest, berry, midnight, gold

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    var colors: [Color] {
        switch self {
        case .ocean: return [Color(hex: 0x4FD8F9), Color(hex: 0x3F6BFF)]
        case .sunset: return [Color(hex: 0xFFB457), Color(hex: 0xFF5E7E)]
        case .aurora: return [Color(hex: 0x3F6BFF), Color(hex: 0x8E6CF6)]
        case .forest: return [Color(hex: 0x43E5A0), Color(hex: 0x10877A)]
        case .berry: return [Color(hex: 0xF76FB1), Color(hex: 0x8E2DE2)]
        case .midnight: return [Color(hex: 0x2B3A67), Color(hex: 0x0B1026)]
        case .gold: return [Color(hex: 0xFFE07A), Color(hex: 0xF0A030)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Brand colors taken from the app logo.
    static let brandCyan = Color(hex: 0x4FD8F9)
    static let brandBlue = Color(hex: 0x3F6BFF)
    static let brandViolet = Color(hex: 0x7B6CF6)
    static let brandSun = Color(hex: 0xFFC845)
}
