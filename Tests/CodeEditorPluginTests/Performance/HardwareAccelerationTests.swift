import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("HardwareAcceleration")
struct HardwareAccelerationTests {
    #if canImport(AppKit)
    @Test("AppKit: apply(true) sets wantsLayer true and returns true")
    func appKitApplyTrueEnablesLayer() {
        let view = NSView()
        let result = HardwareAcceleration.apply(true, to: view)
        #expect(result == true)
        #expect(view.wantsLayer == true)
    }

    @Test("AppKit: apply(false) sets wantsLayer false and returns false")
    func appKitApplyFalseDisablesLayer() {
        let view = NSView()
        view.wantsLayer = true
        let result = HardwareAcceleration.apply(false, to: view)
        #expect(result == false)
        #expect(view.wantsLayer == false)
    }
    #else
    @Test("UIKit: apply is a no-op and always returns true")
    func uiKitApplyIsNoOp() {
        let view = UIView()
        let result = HardwareAcceleration.apply(false, to: view)
        #expect(result == true)
    }
    #endif
}
