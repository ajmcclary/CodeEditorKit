#if canImport(AppKit)
import CodeEditorLSP
import CodeEditorPlugin

extension HoverContents {
    /// Flatten the variant into a single markdown string for the popover.
    var markdownString: String {
        switch self {
        case .string(let value):
            return value

        case .markupContent(let content):
            return content.value

        case .markedStrings(let strings):
            return strings
                .map(Self.render)
                .joined(separator: "\n\n")
        }
    }

    private static func render(_ marked: MarkedString) -> String {
        switch marked {
        case let .string(value):
            return value

        case let .codeBlock(language, value):
            return "```\(language)\n\(value)\n```"
        }
    }
}
#endif
