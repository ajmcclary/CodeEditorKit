import Foundation

/// Errors thrown by `ProjectSearchProvider` implementations.
///
/// The portable adapter previously swallowed regex-compilation failures
/// with `try? NSRegularExpression(...)`, leaving callers staring at zero
/// results with no signal that the pattern was invalid. Surfacing them
/// through this typed error lets the UI display "Invalid regex: ..."
/// instead of silently misleading the user.
public enum ProjectSearchError: LocalizedError, Sendable {
    /// The caller requested regex matching, but `pattern` did not compile.
    /// `underlying` carries the original `NSRegularExpression` error for
    /// diagnostics.
    case invalidRegex(pattern: String, underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case let .invalidRegex(pattern, underlying):
            return "Invalid regex pattern \"\(pattern)\": \(underlying.localizedDescription)"
        }
    }
}
