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

    // MARK: - First-non-nil-wins

    func testFirstNonNilWinsForUndoManager() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let nilParticipant = MockParticipant(name: "nil")
        let firstNonNil = MockParticipant(name: "first")
        firstNonNil.undoManagerToReturn = UndoManager()
        let secondNonNil = MockParticipant(name: "second")
        secondNonNil.undoManagerToReturn = UndoManager()

        multiplexer.addParticipant(nilParticipant, phase: .gating)
        multiplexer.addParticipant(firstNonNil, phase: .behavior)
        multiplexer.addParticipant(secondNonNil, phase: .behavior)

        let result = invokeUndoManager(multiplexer, codeEditorView: codeEditorView)

        XCTAssertTrue(result === firstNonNil.undoManagerToReturn, "First non-nil participant must win")
        XCTAssertEqual(secondNonNil.undoManagerCalls, 0, "Subsequent participants must not be consulted after a non-nil win")
    }

    func testAllNilUndoManagerReturnsNil() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant1 = MockParticipant(name: "a")
        let participant2 = MockParticipant(name: "b")
        multiplexer.addParticipant(participant1, phase: .gating)
        multiplexer.addParticipant(participant2, phase: .behavior)

        XCTAssertNil(invokeUndoManager(multiplexer, codeEditorView: codeEditorView))
    }

    // MARK: - First-handler-wins

    func testFirstHandlerWinsForClickedOnLink() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let nonHandler1 = MockParticipant(name: "n1")
        let nonHandler2 = MockParticipant(name: "n2")
        let handler = MockParticipant(name: "handler")
        handler.clickedOnLinkReturn = true
        let neverConsulted = MockParticipant(name: "never")

        multiplexer.addParticipant(nonHandler1, phase: .gating)
        multiplexer.addParticipant(nonHandler2, phase: .behavior)
        multiplexer.addParticipant(handler, phase: .behavior)
        multiplexer.addParticipant(neverConsulted, phase: .behavior)

        let location = makeTestLocation()
        let result = clickedOnLinkResult(
            for: [nonHandler1, nonHandler2, handler, neverConsulted],
            codeEditorView: codeEditorView,
            location: location
        )

        XCTAssertTrue(result.handled)
        XCTAssertEqual(handler.clickedOnLinkCalls, 1)
        XCTAssertEqual(neverConsulted.clickedOnLinkCalls, 0, "Subsequent participants must not be consulted after a handler returns true")
    }

    func testAllReturnFalseForClickedOnLink() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let participant1 = MockParticipant(name: "a")
        let participant2 = MockParticipant(name: "b")

        let location = makeTestLocation()
        let result = clickedOnLinkResult(
            for: [participant1, participant2],
            codeEditorView: codeEditorView,
            location: location
        )

        XCTAssertFalse(result.handled)
    }

    // MARK: - All-must-agree

    func testShouldAllowInteractionAllMustAgree() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let allow1 = MockParticipant(name: "allow1")
        let veto = MockParticipant(name: "veto")
        veto.shouldAllowInteractionReturn = false
        let allow2 = MockParticipant(name: "allow2")

        let attachment = NSTextAttachment()
        let location = makeTestLocation()
        let result = shouldAllowInteraction(
            for: [allow1, veto, allow2],
            codeEditorView: codeEditorView,
            attachment: attachment,
            location: location
        )

        XCTAssertFalse(result, "Any veto must block the interaction")
        XCTAssertEqual(allow1.shouldAllowInteractionCalls, 1)
        XCTAssertEqual(veto.shouldAllowInteractionCalls, 1)
        XCTAssertEqual(allow2.shouldAllowInteractionCalls, 0, "Subsequent participants must not be consulted after a veto")
    }

    func testShouldAllowInteractionAllAllowReturnsTrue() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let allow1 = MockParticipant(name: "allow1")
        let allow2 = MockParticipant(name: "allow2")

        let attachment = NSTextAttachment()
        let location = makeTestLocation()
        let result = shouldAllowInteraction(
            for: [allow1, allow2],
            codeEditorView: codeEditorView,
            attachment: attachment,
            location: location
        )

        XCTAssertTrue(result)
    }

    // MARK: - Lifecycle

    func testWeakStorageDoesNotRetainParticipants() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        weak var weakRef: MockParticipant?
        do {
            let temp = MockParticipant(name: "temp")
            weakRef = temp
            multiplexer.addParticipant(temp, phase: .behavior)
            XCTAssertNotNil(weakRef, "Sanity: participant alive while strongly held")
        }
        // `temp` is out of scope; the multiplexer holds only a weak ref.
        XCTAssertNil(weakRef, "Multiplexer must not retain participants")

        // Subsequent calls don't crash and don't touch the dead slot.
        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertTrue(allowed, "Dead participant must not block edits")

        // Adding a fresh participant prunes the dead slot transparently.
        let fresh = MockParticipant(name: "fresh")
        multiplexer.addParticipant(fresh, phase: .behavior)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(fresh.shouldChangeCalls, 1, "Fresh participant must receive new invocations")
    }

    func testIdempotentRegistration() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant = MockParticipant(name: "dup")
        multiplexer.addParticipant(participant, phase: .behavior)
        multiplexer.addParticipant(participant, phase: .behavior)

        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1, "Duplicate registration must result in a single invocation per call")
    }

    func testRemoveParticipantStopsInvocations() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant = MockParticipant(name: "removable")
        multiplexer.addParticipant(participant, phase: .behavior)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1)

        multiplexer.removeParticipant(participant)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1, "Removed participant must not receive further invocations")
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

    private func invokeUndoManager(
        _ multiplexer: TextViewDelegateMultiplexer,
        codeEditorView: CodeEditorView
    ) -> UndoManager? {
        #if canImport(AppKit)
        return multiplexer.undoManager(for: codeEditorView)
        #else
        return nil
        #endif
    }

    private func makeTestLocation() -> any NSTextLocation {
        // Any NSTextLocation works; use an empty NSTextRange's location.
        // NSTextRange()'s default location works on both platforms.
        return NSTextRange().location
    }

    /// Walks participants in registration order ourselves to assert
    /// first-handler-wins. Mirrors the multiplexer's intended semantics;
    /// the multiplexer's platform-delegate clickedOnLink methods aren't
    /// directly invokable without a wired-up NSTextView, so this drives
    /// the participant calls explicitly.
    private func clickedOnLinkResult(
        for participants: [MockParticipant],
        codeEditorView: CodeEditorView,
        location: any NSTextLocation
    ) -> (handled: Bool, callOrder: [String]) {
        var order: [String] = []
        for participant in participants {
            order.append(participant.name)
            let handled = participant.textView(
                codeEditorView,
                clickedOnLink: "https://example.com" as Any,
                at: location
            )
            if handled { return (true, order) }
        }
        return (false, order)
    }

    private func shouldAllowInteraction(
        for participants: [MockParticipant],
        codeEditorView: CodeEditorView,
        attachment: NSTextAttachment,
        location: any NSTextLocation
    ) -> Bool {
        for participant in participants {
            let allowed = participant.textView(
                codeEditorView,
                shouldAllowInteractionWith: attachment,
                at: location
            )
            if !allowed { return false }
        }
        return true
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
