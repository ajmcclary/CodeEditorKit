import CodeEditorConfiguration
@testable import CodeEditorLayout
@testable import CodeEditorView
import DesignKitTokens
import Foundation
import SwiftUI
import Testing

@Suite("Fold chevron")
struct FoldChevronTests {
    @Test("Animation respects config.performance.animateCodeFolding=true")
    func animationOn() {
        var config = EditorConfiguration()
        config.performance.animateCodeFolding = true
        let resolved = FoldChevronAnimation.resolved(for: config)
        #expect(resolved == Tokens.Animation.foldChevron)
    }

    @Test("Animation is nil when animateCodeFolding=false (instant rotation)")
    func animationOff() {
        var config = EditorConfiguration()
        config.performance.animateCodeFolding = false
        let resolved = FoldChevronAnimation.resolved(for: config)
        #expect(resolved == nil)
    }

    @Test("Click target spans 16×lineHeight at the leading edge of the gutter")
    func clickTargetGeometry() {
        let lineHeight: CGFloat = 18
        let rect = FoldChevronHitTester.hitRect(forLineHeight: lineHeight, atY: 36)
        #expect(rect.width == 16)
        #expect(abs(rect.height - lineHeight) < 0.01)
        #expect(rect.minY == 36)
        #expect(rect.minX == 0)
    }

    @Test("chevronHit returns the matching line index when point falls inside a hit rect")
    func chevronHitMatch() {
        let lineYs: [CGFloat] = [0, 18, 36, 54, 72]
        let lineHeight: CGFloat = 18
        let hit = FoldChevronHitTester.chevronHit(
            at: CGPoint(x: 4, y: 38),
            lineHeight: lineHeight,
            visibleLineYs: lineYs
        )
        #expect(hit == 2)
    }

    @Test("chevronHit returns nil for a point outside every chevron rect")
    func chevronHitMiss() {
        let lineYs: [CGFloat] = [0, 18, 36]
        let lineHeight: CGFloat = 18
        let hit = FoldChevronHitTester.chevronHit(
            at: CGPoint(x: 200, y: 4),
            lineHeight: lineHeight,
            visibleLineYs: lineYs
        )
        #expect(hit == nil)
    }
}
