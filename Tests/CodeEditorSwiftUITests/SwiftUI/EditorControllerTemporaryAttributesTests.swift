#if canImport(AppKit)
import AppKit
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import Testing

@Suite("EditorController temporary attributes")
struct EditorControllerTemporaryAttributesTests {
    @Test("apply adds attributes when attached")
    @MainActor
    func applyAddsAttributesWhenAttached() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "let x = 1"
        controller.attach(to: view)

        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemRed],
            to: NSRange(location: 0, length: 3)
        )

        let color = view.textStorage?.attribute(
            .underlineColor, at: 0, effectiveRange: nil
        ) as? NSColor
        #expect(color == .systemRed)
    }

    @Test("clearAll removes everything applied")
    @MainActor
    func clearAllRemovesEverything() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "let x = 1"
        controller.attach(to: view)
        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemRed],
            to: NSRange(location: 0, length: 3)
        )

        controller.clearAllTemporaryAttributes()

        let color = view.textStorage?.attribute(
            .underlineColor, at: 0, effectiveRange: nil
        ) as? NSColor
        #expect(color == nil)
    }

    @Test("clear in range removes only overlapping keys")
    @MainActor
    func clearInRangeRemovesOnlyOverlapping() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "let x = 1; let y = 2"
        controller.attach(to: view)
        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemRed],
            to: NSRange(location: 0, length: 3)
        )
        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemBlue],
            to: NSRange(location: 11, length: 3)
        )

        controller.clearTemporaryAttributes(in: NSRange(location: 0, length: 3))

        let firstColor = view.textStorage?.attribute(
            .underlineColor, at: 0, effectiveRange: nil
        ) as? NSColor
        let secondColor = view.textStorage?.attribute(
            .underlineColor, at: 11, effectiveRange: nil
        ) as? NSColor
        #expect(firstColor == nil)
        #expect(secondColor == .systemBlue)
    }

    @Test("unattached controller is a safe no-op")
    @MainActor
    func unattachedIsNoOp() {
        let controller = EditorController()
        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemRed],
            to: NSRange(location: 0, length: 3)
        )
        controller.clearTemporaryAttributes(in: NSRange(location: 0, length: 3))
        controller.clearAllTemporaryAttributes()
        #expect(!controller.isAttached)
    }
}
#endif
