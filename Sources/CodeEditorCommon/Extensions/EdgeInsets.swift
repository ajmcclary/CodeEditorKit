import CoreGraphics
import Foundation

/// Framework alias for `EdgeInsets` so external code can disambiguate from
/// `SwiftUI.EdgeInsets` without resorting to fully-qualified
/// `CodeEditorKit.EdgeInsets` (which fails because the module name shadows
/// a public struct of the same name).
public typealias FrameworkEdgeInsets = EdgeInsets

/// Edge insets. Fields are mutable so hosts can drive them through SwiftUI
/// bindings or write-key-paths without rebuilding the whole struct.
public struct EdgeInsets: Sendable, Equatable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = Self()
}
