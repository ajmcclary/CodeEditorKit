import Foundation

/// Document URIs for LSP traffic.
///
/// `"file://\(path)"` is not a URI: `#`, `?` and `%` in a path are read as
/// URI syntax (the server truncates the path at `#`), and a server that
/// re-encodes a space reports diagnostics under a different string.
package enum LSPDocumentURI {
    /// The percent-encoded `file:` URI of an absolute file path.
    package static func uri(forFilePath filePath: String) -> String {
        URL(fileURLWithPath: filePath).absoluteString
    }

    /// `uri` in the form `uri(forFilePath:)` produces, so the same file
    /// always has the same key however the server chose to encode it.
    /// Non-`file:` URIs are returned unchanged.
    package static func canonical(_ uri: String) -> String {
        guard let url = URL(string: uri), url.isFileURL else { return uri }
        return URL(fileURLWithPath: url.path).absoluteString
    }
}
