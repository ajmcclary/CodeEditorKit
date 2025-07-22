import Foundation

// MARK: - Type Aliases

/// Type alias for LSP Diagnostic to avoid naming conflicts with Plugin types
/// Since both LSP and Plugin systems define similar types like Diagnostic,
/// we use these aliases to clearly distinguish between them.
public typealias LSPDiagnostic = Diagnostic

/// Type alias for LSP DiagnosticSeverity
public typealias LSPDiagnosticSeverity = DiagnosticSeverity

/// Type alias for LSP DiagnosticTag
public typealias LSPDiagnosticTag = DiagnosticTag

/// Type alias for LSP DiagnosticRelatedInformation
public typealias LSPDiagnosticRelatedInformation = DiagnosticRelatedInformation
