import Foundation

extension Tokens {
    /// sRGB color with alpha. UI-framework agnostic.
    ///
    /// Bridging to `SwiftUI.Color`, `NSColor`, or `UIColor` lives in
    /// `CodeEditorPlugin`/`CodeEditorUI`, not here.
    public struct Color: Hashable, Sendable, Codable {
        /// Red component, 0–255.
        public let r: UInt8
        /// Green component, 0–255.
        public let g: UInt8
        /// Blue component, 0–255.
        public let b: UInt8
        /// Alpha, 0.0–1.0.
        public let alpha: Double

        public init(r: UInt8, g: UInt8, b: UInt8, alpha: Double = 1) {
            self.r = r
            self.g = g
            self.b = b
            self.alpha = alpha
        }

        /// Build from a 24-bit RGB hex literal, e.g. `0x0A84FF`.
        public init(hex: UInt32, alpha: Double = 1) {
            self.r = UInt8((hex >> 16) & 0xFF)
            self.g = UInt8((hex >> 8) & 0xFF)
            self.b = UInt8(hex & 0xFF)
            self.alpha = alpha
        }

        /// Parse from a hex string, with or without leading `#`. Accepts
        /// 6-digit (RRGGBB) or 8-digit (RRGGBBAA) forms. Returns nil on
        /// malformed input.
        public init?(hexString: String) {
            var s = hexString
            if s.hasPrefix("#") { s.removeFirst() }
            guard s.count == 6 || s.count == 8,
                  s.allSatisfy(\.isHexDigit) else { return nil }
            guard let rgb = UInt32(s.prefix(6), radix: 16) else { return nil }
            self.r = UInt8((rgb >> 16) & 0xFF)
            self.g = UInt8((rgb >> 8) & 0xFF)
            self.b = UInt8(rgb & 0xFF)
            if s.count == 8 {
                guard let a = UInt32(s.suffix(2), radix: 16) else { return nil }
                self.alpha = Double(a) / 255.0
            } else {
                self.alpha = 1
            }
        }

        /// Serialize as `#RRGGBB` (alpha == 1) or `#RRGGBBAA` (alpha < 1).
        /// Alpha component is rounded to the nearest 0–255 byte.
        public var hexString: String {
            if alpha >= 1.0 {
                return String(format: "#%02X%02X%02X", r, g, b)
            }
            let a = UInt8((alpha * 255.0).rounded())
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }
}
