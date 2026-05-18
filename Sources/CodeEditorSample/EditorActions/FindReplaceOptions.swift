import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorView
import Foundation

/// Hashable bag of the three search toggles the sample overlay exposes.
/// Lives in the sample target; the framework's `SearchOptions` is the
/// authoritative type and this value bridges to it on demand.
struct FindReplaceOptions: Hashable, Sendable {
    var caseSensitive: Bool = false
    var wholeWord: Bool = false
    var useRegularExpression: Bool = false
}

extension FindReplaceOptions {
    /// Bridge to the framework type. Sample owns the colour choices for
    /// `highlightColor` and `currentMatchColor`; the framework stays
    /// colour-agnostic.
    func toSearchOptions() -> SearchOptions {
        var options = SearchOptions()
        options.caseSensitive = caseSensitive
        options.wholeWord = wholeWord
        options.useRegularExpression = useRegularExpression
        options.highlightColor = PlatformColor.findHighlight
        options.currentMatchColor = PlatformColor.findActiveMatch
        return options
    }
}
