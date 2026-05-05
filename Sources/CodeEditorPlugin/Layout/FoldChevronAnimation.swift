import CodeEditorDesignTokens
import Foundation
import SwiftUI

/// Resolves the SwiftUI animation used for fold-chevron rotation given the
/// editor's performance configuration. Returns nil when animations are
/// disabled — call sites then mutate the rotation state without wrapping
/// it in `withAnimation`, producing an instant snap.
public enum FoldChevronAnimation {
    /// Looks up the animation for the supplied configuration. The
    /// `performance.animateCodeFolding` flag is the single gate.
    public static func resolved(for config: EditorConfiguration) -> Animation? {
        guard config.performance.animateCodeFolding else { return nil }
        return Tokens.Animation.foldChevron
    }
}
