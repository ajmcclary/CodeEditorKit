import CodeEditorDesignTokens
import Foundation

/// One entry from the `players` array. `players[0]` is the user's local
/// caret/selection; subsequent entries are reserved for collaborative
/// editing and preserved on roundtrip even though the editor draws only [0].
public struct Player: Hashable, Sendable, Codable {
    /// Caret color.
    public let cursor: Tokens.Color
    /// Selection fill color.
    public let selection: Tokens.Color
    /// Optional player-row background tint.
    public let background: Tokens.Color?

    /// Memberwise builder.
    public init(cursor: Tokens.Color, selection: Tokens.Color, background: Tokens.Color? = nil) {
        self.cursor = cursor
        self.selection = selection
        self.background = background
    }

    private enum CodingKeys: String, CodingKey {
        case cursor, selection, background
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        let cursorHex = try container.decode(String.self, forKey: .cursor)
        let selectionHex = try container.decode(String.self, forKey: .selection)
        let cursorColor = ZedColorBridge.parse(cursorHex, path: "players.cursor", warnings: warnings)
        let selectionColor = ZedColorBridge.parse(
            selectionHex, path: "players.selection", warnings: warnings
        )
        guard let cursor = cursorColor, let selection = selectionColor else {
            throw DecodingError.dataCorruptedError(
                forKey: .cursor,
                in: container,
                debugDescription: "Player.cursor/selection malformed hex"
            )
        }
        self.cursor = cursor
        self.selection = selection
        if let bgHex = try container.decodeIfPresent(String.self, forKey: .background) {
            self.background = ZedColorBridge.parse(bgHex, path: "players.background", warnings: warnings)
        } else {
            self.background = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ZedColorBridge.encode(cursor), forKey: .cursor)
        try container.encode(ZedColorBridge.encode(selection), forKey: .selection)
        try container.encodeIfPresent(
            background.map(ZedColorBridge.encode), forKey: .background
        )
    }
}
