import Foundation

extension Tokens {
    /// sRGB color with alpha. UI-framework agnostic.
    ///
    /// Bridging to `SwiftUI.Color`, `NSColor`, or `UIColor` lives in
    /// `CodeEditorPlugin`/`CodeEditorUI`, not here.
    public struct Color: Hashable, Sendable, Codable {
        /// Red component, 0–255.
        public let red: UInt8
        /// Green component, 0–255.
        public let green: UInt8
        /// Blue component, 0–255.
        public let blue: UInt8
        /// Alpha, 0.0–1.0.
        public let alpha: Double

        /// Build from explicit channel values.
        public init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        /// Build from a 24-bit RGB hex literal, e.g. `0x0A84FF`.
        public init(hex: UInt32, alpha: Double = 1) {
            self.red = UInt8((hex >> 16) & 0xFF)
            self.green = UInt8((hex >> 8) & 0xFF)
            self.blue = UInt8(hex & 0xFF)
            self.alpha = alpha
        }

        /// Parse from a hex string, with or without leading `#`. Accepts
        /// 6-digit (RRGGBB) or 8-digit (RRGGBBAA) forms. Returns nil on
        /// malformed input.
        public init?(hexString: String) {
            var trimmed = hexString
            if trimmed.hasPrefix("#") { trimmed.removeFirst() }
            guard trimmed.count == 6 || trimmed.count == 8,
                  trimmed.allSatisfy(\.isHexDigit) else { return nil }
            guard let rgb = UInt32(trimmed.prefix(6), radix: 16) else { return nil }
            self.red = UInt8((rgb >> 16) & 0xFF)
            self.green = UInt8((rgb >> 8) & 0xFF)
            self.blue = UInt8(rgb & 0xFF)
            if trimmed.count == 8 {
                guard let alphaByte = UInt32(trimmed.suffix(2), radix: 16) else { return nil }
                self.alpha = Double(alphaByte) / 255.0
            } else {
                self.alpha = 1
            }
        }

        /// Serialize as `#RRGGBB` (alpha == 1) or `#RRGGBBAA` (alpha < 1).
        /// Alpha component is rounded to the nearest 0–255 byte.
        public var hexString: String {
            if alpha >= 1.0 {
                return String(format: "#%02X%02X%02X", red, green, blue)
            }
            let alphaByte = UInt8((alpha * 255.0).rounded())
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alphaByte)
        }
    }
}
