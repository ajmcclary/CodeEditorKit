import CodeEditorDesignTokens
import Foundation
import SwiftUI

extension Tokens.Animation {
    /// Fold-chevron rotation: `durQuick` (200ms) at `easeOutSoft`.
    /// The single named animation call site in the editor restyle;
    /// future named animations land alongside this one.
    public static var foldChevron: Animation {
        Animation.timingCurve(easing: easeOutSoft, duration: durQuick)
    }
}
