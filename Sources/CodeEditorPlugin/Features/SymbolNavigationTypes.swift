import Foundation

// MARK: - Breadcrumb

/// Breadcrumb item
public struct BreadcrumbItem: Identifiable, Sendable {
    public let id = UUID()
    public let symbol: DocumentSymbol
    public let level: Int
}

// MARK: - Symbol Navigation Configuration

/// Symbol navigation configuration
public struct SymbolNavigationConfiguration: Sendable {
    /// Whether symbol navigation is enabled
    public var enabled = true
    /// Whether to show symbol markers in the gutter
    public var showInGutter = true
    /// Whether to show breadcrumb navigation at the top
    public var showBreadcrumbs = true
    /// Maximum number of items to show in breadcrumbs
    public var maxBreadcrumbItems = 5
    /// Delay before updating symbols after text changes
    public var updateDelay: TimeInterval = 0.3
    /// Whether to include anonymous symbols in navigation
    public var includeAnonymousSymbols = false
}
