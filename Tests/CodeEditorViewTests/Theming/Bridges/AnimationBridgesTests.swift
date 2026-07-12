import CodeEditorDesignTokens
@testable import CodeEditorView
import Foundation
import SwiftUI
import Testing

@Suite("Animation bridges")
struct AnimationBridgesTests {
    @Test("Easing produces a timingCurve animation with the same control points")
    func easingProducesTimingCurve() {
        let easing = Tokens.Easing(0.16, 1.00, 0.30, 1.00)
        let duration: Duration = .milliseconds(200)
        let bridge = Animation.timingCurve(easing: easing, duration: duration)
        let direct = Animation.timingCurve(0.16, 1.00, 0.30, 1.00, duration: 0.2)
        #expect(bridge == direct)
    }

    @Test("foldChevron pairs durQuick with easeOutSoft")
    func foldChevronShape() {
        let bridge = Tokens.Animation.foldChevron
        let expected = Animation.timingCurve(
            easing: Tokens.Animation.easeOutSoft,
            duration: Tokens.Animation.durQuick
        )
        #expect(bridge == expected)
    }
}
