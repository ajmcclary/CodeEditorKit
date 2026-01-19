import Foundation

// MARK: - Gutter Debug Support

/// Manages debugging and diagnostic state for the gutter
///
/// This class handles breakpoint and diagnostic line tracking,
/// separating debug concerns from the main GutterViewModel.
@MainActor
public final class GutterDebugSupport {
    // MARK: - Properties

    /// Set of line numbers that have breakpoints
    public private(set) var breakpoints: Set<Int> = []

    /// Set of line numbers that have diagnostics (errors/warnings)
    public private(set) var diagnosticLines: Set<Int> = []

    /// Callback triggered when state changes (for triggering redraws)
    public var onStateChanged: (() -> Void)?

    // MARK: - Initialization

    /// Creates a new gutter debug support instance
    public init() {}

    // MARK: - Breakpoint Management

    /// Sets breakpoints for debugging integration
    /// - Parameter lines: Set of line numbers that have breakpoints
    public func setBreakpoints(_ lines: Set<Int>) {
        breakpoints = lines
        onStateChanged?()
    }

    /// Adds a breakpoint at the specified line
    /// - Parameter line: Line number to add breakpoint
    public func addBreakpoint(at line: Int) {
        breakpoints.insert(line)
        onStateChanged?()
    }

    /// Removes a breakpoint from the specified line
    /// - Parameter line: Line number to remove breakpoint
    public func removeBreakpoint(at line: Int) {
        breakpoints.remove(line)
        onStateChanged?()
    }

    /// Checks if a line has a breakpoint
    /// - Parameter line: Line number to check
    /// - Returns: True if the line has a breakpoint
    public func hasBreakpoint(at line: Int) -> Bool {
        breakpoints.contains(line)
    }

    /// Toggles a breakpoint at the specified line
    /// - Parameter line: Line number to toggle breakpoint
    public func toggleBreakpoint(at line: Int) {
        if breakpoints.contains(line) {
            breakpoints.remove(line)
        } else {
            breakpoints.insert(line)
        }
        onStateChanged?()
    }

    // MARK: - Diagnostic Management

    /// Sets diagnostic lines for error/warning integration
    /// - Parameter lines: Set of line numbers that have diagnostics
    public func setDiagnosticLines(_ lines: Set<Int>) {
        diagnosticLines = lines
        onStateChanged?()
    }

    /// Adds a diagnostic at the specified line
    /// - Parameter line: Line number to add diagnostic
    public func addDiagnostic(at line: Int) {
        diagnosticLines.insert(line)
        onStateChanged?()
    }

    /// Removes a diagnostic from the specified line
    /// - Parameter line: Line number to remove diagnostic
    public func removeDiagnostic(at line: Int) {
        diagnosticLines.remove(line)
        onStateChanged?()
    }

    /// Checks if a line has a diagnostic
    /// - Parameter line: Line number to check
    /// - Returns: True if the line has a diagnostic
    public func hasDiagnostic(at line: Int) -> Bool {
        diagnosticLines.contains(line)
    }

    /// Clears all diagnostics
    public func clearDiagnostics() {
        diagnosticLines.removeAll()
        onStateChanged?()
    }

    /// Clears all breakpoints
    public func clearBreakpoints() {
        breakpoints.removeAll()
        onStateChanged?()
    }

    /// Clears all debug state (breakpoints and diagnostics)
    public func clearAll() {
        breakpoints.removeAll()
        diagnosticLines.removeAll()
        onStateChanged?()
    }
}
