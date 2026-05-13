/// Zero-based source position. Matches the LSP convention (UTF-16 character
/// offset within the line) so callers translating to an LSP `Position` do not
/// need per-call arithmetic, but this type imports no LSP types itself.
public struct SourcePosition: Sendable, Hashable {
    public let line: Int
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}
