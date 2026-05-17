import Foundation

/// A `CodingKey` that round-trips any string. Used by `ThemeStyle.init(from:)`
/// to read Zed JSON's flat dotted keys (e.g., `editor.gutter.background`,
/// `text.muted`).
struct DynamicCodingKey: CodingKey, Hashable {
    package let stringValue: String
    package var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue _: Int) { nil }
}
