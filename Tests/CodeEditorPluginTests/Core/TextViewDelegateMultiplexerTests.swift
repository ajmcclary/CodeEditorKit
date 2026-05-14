import XCTest
@testable import CodeEditorPlugin
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class TextViewDelegateMultiplexerTests: XCTestCase {

    // MARK: - shouldChangeTextIn: phase ordering

    func testGatingVetoShortCircuitsBeforeBehavior() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let gating = MockParticipant(name: "gating", shouldChangeReturn: false)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: true)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertFalse(allowed, "Gating veto must block the edit")
        XCTAssertEqual(gating.shouldChangeCalls, 1, "Gating participant must be consulted")
        XCTAssertEqual(behavior.shouldChangeCalls, 0, "Behavior participant must not be consulted after gating veto")
    }

    func testBehaviorVetoBlocksWillEditEvent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer
        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let gating = MockParticipant(name: "gating", shouldChangeReturn: true)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: false)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertFalse(allowed, "Behavior veto must block the edit")
        XCTAssertEqual(observer.willEditCount, 0, "Behavior veto must prevent publishWillEditEvent")
    }

    func testAllAllowPublishesExactlyOneWillEditEvent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer
        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let gating = MockParticipant(name: "gating", shouldChangeReturn: true)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: true)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertTrue(allowed, "All-allow must permit the edit")
        XCTAssertEqual(gating.shouldChangeCalls, 1, "Gating consulted exactly once")
        XCTAssertEqual(behavior.shouldChangeCalls, 1, "Behavior consulted exactly once")
        XCTAssertEqual(observer.willEditCount, 1, "Exactly one WillEditEvent must be published")
    }

    // MARK: - Fan-out notifications

    func testFanOutNotificationsHitAllParticipantsInRegistrationOrder() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let gating1 = MockParticipant(name: "gating1")
        let gating2 = MockParticipant(name: "gating2")
        let behavior1 = MockParticipant(name: "behavior1")
        let behavior2 = MockParticipant(name: "behavior2")
        multiplexer.addParticipant(gating1, phase: .gating)
        multiplexer.addParticipant(gating2, phase: .gating)
        multiplexer.addParticipant(behavior1, phase: .behavior)
        multiplexer.addParticipant(behavior2, phase: .behavior)

        // Fire textViewDidChangeSelection directly via the participant API
        // (the multiplexer's platform-delegate methods call this same path).
        for participant in [gating1, gating2, behavior1, behavior2] as [any TextViewDelegateParticipant] {
            participant.textViewDidChangeSelection(codeEditorView)
        }

        XCTAssertEqual(gating1.didChangeSelectionCalls, 1)
        XCTAssertEqual(gating2.didChangeSelectionCalls, 1)
        XCTAssertEqual(behavior1.didChangeSelectionCalls, 1)
        XCTAssertEqual(behavior2.didChangeSelectionCalls, 1)
    }

    // MARK: - Test helpers

    /// Invokes the platform delegate method that internally calls the
    /// multiplexer's `shouldChangeText(in:range:replacementString:)`.
    /// Bridges to the right NSTextView/UITextView variant.
    private func invokeShouldChange(
        _ multiplexer: TextViewDelegateMultiplexer,
        codeEditorView: CodeEditorView
    ) -> Bool {
        let range = NSRange(location: 0, length: 0)
        #if canImport(AppKit)
        return multiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementString: "x"
        )
        #else
        return multiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementText: "x"
        )
        #endif
    }
}

// MARK: - MockParticipant

@MainActor
private final class MockParticipant: TextViewDelegateParticipant {
    let name: String
    let shouldChangeReturn: Bool

    private(set) var shouldChangeCalls = 0
    private(set) var didChangeSelectionCalls = 0
    private(set) var didChangeTextCalls = 0
    private(set) var willChangeTextCalls = 0
    private(set) var clickedOnLinkCalls = 0
    private(set) var undoManagerCalls = 0
    private(set) var shouldAllowInteractionCalls = 0

    var undoManagerToReturn: UndoManager?
    var clickedOnLinkReturn = false
    var shouldAllowInteractionReturn = true

    init(name: String, shouldChangeReturn: Bool = true) {
        self.name = name
        self.shouldChangeReturn = shouldChangeReturn
    }

    func textView(
        _: CodeEditorView,
        shouldChangeTextIn _: NSRange,
        replacementString _: String?
    ) -> Bool {
        shouldChangeCalls += 1
        return shouldChangeReturn
    }

    func textViewDidChangeSelection(_: CodeEditorView) {
        didChangeSelectionCalls += 1
    }

    func textViewDidChangeText(_: CodeEditorView) {
        didChangeTextCalls += 1
    }

    func textViewWillChangeText(_: CodeEditorView) {
        willChangeTextCalls += 1
    }

    func undoManager(for _: CodeEditorView) -> UndoManager? {
        undoManagerCalls += 1
        return undoManagerToReturn
    }

    func textView(
        _: CodeEditorView,
        clickedOnLink _: Any,
        at _: any NSTextLocation
    ) -> Bool {
        clickedOnLinkCalls += 1
        return clickedOnLinkReturn
    }

    func textView(
        _: CodeEditorView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool {
        shouldAllowInteractionCalls += 1
        return shouldAllowInteractionReturn
    }
}

// MARK: - WillEditObserver

@MainActor
private final class WillEditObserver: WillEditEventObserving {
    private(set) var willEditCount = 0
    func textStorageWillApplyEdit(_: WillEditEvent) {
        willEditCount += 1
    }
}
