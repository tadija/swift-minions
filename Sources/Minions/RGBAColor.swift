#if canImport(Foundation)

import Foundation

// MARK: - RGBAColor

/// Helper type for working with colors.
public struct RGBAColor {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(
        red: Double = 0,
        green: Double = 0,
        blue: Double = 0,
        alpha: Double = 1
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: - RGBAColor Helpers

public extension RGBAColor {

    /// Init with RGB
    /// - Parameter rgb: ie. 0xf5f5f5
    init(rgb: UInt32) {
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    /// Init with RGBA
    /// - Parameter rgba: ie. 0xf5f5f5ff
    init(rgba: UInt32) {
        let red = Double((rgba >> 24) & 0xFF) / 255.0
        let green = Double((rgba >> 16) & 0xFF) / 255.0
        let blue = Double((rgba >> 8) & 0xFF) / 255.0
        let alpha = Double(rgba & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Init with HEX
    /// - Parameter hex: ie. "#f5f5f5" or "#f5f5f5ff"
    init(hex: String) {
        var input = hex.replacingOccurrences(of: "#", with: "")
        if input.count == 6 { input.append("FF") }

        guard input.count == 8 else {
            self = RGBAColor(); return
        }

        var rgbaValue: UInt64 = 0
        let scanner = Scanner(string: input)
        scanner.scanHexInt64(&rgbaValue)

        self = RGBAColor(rgba: UInt32(rgbaValue))
    }

}

#endif

// MARK: - Color Helpers

#if canImport(SwiftUI)

import SwiftUI

public extension RGBAColor {
    func toColor() -> Color {
        .init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

#endif

// MARK: - UIColor Helpers

#if canImport(UIKit)

import UIKit

public extension RGBAColor {
    func toUIColor() -> UIColor {
        .init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#endif

// MARK: - NSColor Helpers

#if canImport(AppKit)

import AppKit

public extension RGBAColor {
    func toNSColor() -> NSColor {
        .init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#endif

// MARK: - CGColor Helpers

#if canImport(CoreGraphics)

import CoreGraphics

public extension CGColor {
    /// Converts `CGColor` to its hex string representation.
    /// - Parameter alpha: flag for including alpha component (defaults to `false`)
    /// - Returns: hex string
    func toHex(alpha: Bool = false) -> String {
        guard let components = components, components.count >= 3 else {
            return .init()
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(
                format: "#%02lX%02lX%02lX%02lX",
                lroundf(r * 255),
                lroundf(g * 255),
                lroundf(b * 255),
                lroundf(a * 255)
            )
        } else {
            return String(
                format: "#%02lX%02lX%02lX",
                lroundf(r * 255),
                lroundf(g * 255),
                lroundf(b * 255)
            )
        }
    }
}

#endif
