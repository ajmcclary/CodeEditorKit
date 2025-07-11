import Foundation

/// Unified annotation type enumeration with associated display properties.
///
/// This enum consolidates the mapping of annotation types to their visual representation,
/// reducing code duplication and improving maintainability.
public enum AnnotationKind: String, CaseIterable, Sendable {
    case info = "INFO"
    case note = "NOTE"
    case todo = "TODO"
    case fixme = "FIXME"
    case warning = "WARNING"
    case error = "ERROR"
    
    /// The color associated with this annotation type
    public var color: PlatformColor {
        switch self {
        case .info, .note, .todo:
            return PlatformColors.systemBlue

        case .fixme:
            return PlatformColors.systemOrange

        case .warning:
            return PlatformColors.systemYellow

        case .error:
            return PlatformColors.systemRed
        }
    }
    
    /// The SF Symbol icon name for this annotation type
    public var iconName: String {
        switch self {
        case .info, .note:
            return "info.circle"

        case .todo:
            return "checkmark.circle"

        case .fixme:
            return "wrench"

        case .warning:
            return "exclamationmark.triangle"

        case .error:
            return "xmark.circle"
        }
    }
    
    /// Initialize from a MessageLineAnnotation.AnnotationKind
    public init(from messageKind: MessageLineAnnotation.AnnotationKind) {
        switch messageKind {
        case .info:
            self = .info

        case .warning:
            self = .warning

        case .error:
            self = .error
        }
    }
    
    /// Infer annotation kind from message content
    public static func infer(from message: String) -> Self {
        let lowercased = message.lowercased()
        
        if lowercased.contains("todo") {
            return .todo
        } else if lowercased.contains("fixme") {
            return .fixme
        } else if lowercased.contains("warning") {
            return .warning
        } else if lowercased.contains("error") {
            return .error
        } else {
            return .note
        }
    }
}
