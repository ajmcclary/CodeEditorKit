import Foundation

/// Type aliases to resolve naming conflicts between LSP types and Plugin types
///
/// Since both LSP and Plugin systems define similar types like Diagnostic,
/// we use these aliases to clearly distinguish between them.

// Use the LSP Diagnostic type by default in LSP code
public typealias LSPDiagnostic = Diagnostic

// Use specific prefixes when ambiguity exists
public typealias LSPDiagnosticSeverity = DiagnosticSeverity
public typealias LSPDiagnosticTag = DiagnosticTag
public typealias LSPDiagnosticRelatedInformation = DiagnosticRelatedInformation
