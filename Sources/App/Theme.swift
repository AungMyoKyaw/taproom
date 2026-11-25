import AppKit
import SwiftUI

enum TaproomTheme {
    // Warm Amber/Copper brand accent (#F59E0B dark / #B45309 light)
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.961, green: 0.620, blue: 0.043, alpha: 1.0)
            : NSColor(srgbRed: 0.706, green: 0.325, blue: 0.035, alpha: 1.0)
    })

    static let onAccent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.067, green: 0.071, blue: 0.078, alpha: 1.0)
            : .white
    })

    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.078, green: 0.086, blue: 0.098, alpha: 1.0)
            : NSColor(srgbRed: 0.969, green: 0.973, blue: 0.980, alpha: 1.0)
    })

    static let surfaceElevated = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.110, green: 0.122, blue: 0.141, alpha: 1.0)
            : .white
    })

    static let border = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.165, green: 0.180, blue: 0.208, alpha: 1.0)
            : NSColor(srgbRed: 0.886, green: 0.898, blue: 0.918, alpha: 1.0)
    })

    static let statusCurrent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.063, green: 0.725, blue: 0.506, alpha: 1.0)
            : NSColor(srgbRed: 0.020, green: 0.588, blue: 0.412, alpha: 1.0)
    })

    static let statusOutdated = accent

    static let statusError = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.973, green: 0.443, blue: 0.443, alpha: 1.0)
            : NSColor(srgbRed: 0.863, green: 0.149, blue: 0.149, alpha: 1.0)
    })

    static let formulaBadgeBg = Color.blue.opacity(0.14)
    static let formulaBadgeFg = Color.blue
    static let caskBadgeBg = Color.purple.opacity(0.14)
    static let caskBadgeFg = Color.purple

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func taproomCard(cornerRadius: CGFloat = 10, padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(TaproomTheme.border, lineWidth: 1)
            )
    }
}
