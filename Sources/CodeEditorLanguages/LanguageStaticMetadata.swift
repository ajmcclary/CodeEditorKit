import Foundation

// MARK: - Language Static Metadata (deprecated)

/// Backward-compatibility alias for `LanguageDescriptor`.
///
/// All language metadata now lives in `LanguageDescriptor`. This typealias
/// exists so that code referencing the old name continues to compile during
/// the transition. New code should use `LanguageDescriptor` directly.
@available(*, deprecated, message: "Use LanguageDescriptor instead")
internal typealias LanguageStaticMetadata = LanguageDescriptor
