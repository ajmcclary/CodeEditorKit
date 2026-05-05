import Testing
import Foundation
@testable import CodeEditorDesignTokens

@Suite("Tokens.Animation")
struct AnimationTests {

    @Test("durations match CSS milliseconds")
    func durations() {
        #expect(Tokens.Animation.durInstant == .milliseconds(100))
        #expect(Tokens.Animation.durFast == .milliseconds(150))
        #expect(Tokens.Animation.durQuick == .milliseconds(200))
        #expect(Tokens.Animation.durDrawer == .milliseconds(250))
        #expect(Tokens.Animation.durControl == .milliseconds(300))
        #expect(Tokens.Animation.durPage == .milliseconds(350))
        #expect(Tokens.Animation.durSection == .milliseconds(400))
        #expect(Tokens.Animation.durScreen == .milliseconds(500))
        #expect(Tokens.Animation.durVerySlow == .milliseconds(600))
    }

    @Test("durations are strictly monotonic")
    func durationsMonotonic() {
        let scale = [
            Tokens.Animation.durInstant, Tokens.Animation.durFast,
            Tokens.Animation.durQuick, Tokens.Animation.durDrawer,
            Tokens.Animation.durControl, Tokens.Animation.durPage,
            Tokens.Animation.durSection, Tokens.Animation.durScreen,
            Tokens.Animation.durVerySlow
        ]
        for i in 1..<scale.count {
            #expect(scale[i] > scale[i - 1])
        }
    }

    @Test("easings match CSS bezier values")
    func easings() {
        #expect(Tokens.Animation.easeOutSoft == Tokens.Easing(0.16, 1.00, 0.30, 1.00))
        #expect(Tokens.Animation.easeInOutSoft == Tokens.Easing(0.25, 0.80, 0.25, 1.00))
        #expect(Tokens.Animation.easeSpringSnappy == Tokens.Easing(0.22, 1.00, 0.36, 1.00))
    }
}
