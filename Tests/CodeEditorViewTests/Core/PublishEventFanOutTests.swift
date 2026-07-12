#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
import Combine
import XCTest

/// Verifies that `CodeEditorView` events fan out through `publishEvent(_:)`
/// into a customer-supplied `UnifiedEventSystem`. This guards the
/// `.eventSystem(_:)` SwiftUI modifier contract — without these tests the
/// modifier silently delivers nothing.
@MainActor
final class PublishEventFanOutTests: XCTestCase {
    /// Make a hosted `CodeEditorView` with a `UnifiedEventSystem` wired
    /// through the framework runtime so `publishEvent(_:)` fans out.
    private func makeHostedView(
        text: String = ""
    ) throws -> (CodeEditorView, UnifiedEventSystem, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = text
        window.contentView = container
        window.makeKeyAndOrderFront(nil)

        let eventSystem = UnifiedEventSystem()
        container.textView.runtime.update(eventSystem: eventSystem)

        return (container.textView, eventSystem, window)
    }

    func testTextDidChangeFansOutToEventSystem() throws {
        let (view, eventSystem, window) = try makeHostedView(text: "alpha")
        defer { window.close() }

        var received: [String] = []
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .textDidChange(let text) = event { received.append(text) }
            }
            .store(in: &cancellables)

        view.string = "alpha\nbeta"

        // textDidChange is dispatched on the main queue via DispatchQueue.main.async
        // from textStorageDidProcessEditing; let the runloop drain so the event lands.
        let expectation = expectation(description: "textDidChange delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            received.last,
            "alpha\nbeta",
            "Setting `string` should fan out a textDidChange event into the customer-supplied UnifiedEventSystem."
        )
        XCTAssertEqual(
            view.runtime.dependencies.eventBus.recentEvents { event in
                if case .textDidChange("alpha\nbeta") = event { return true }
                return false
            }.count,
            1,
            "A text change must enter the canonical bus exactly once."
        )
    }

    func testSelectionDidChangeFansOutToEventSystem() throws {
        let (view, eventSystem, window) = try makeHostedView(text: "hello world")
        defer { window.close() }

        var received: [NSRange] = []
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .textSelectionDidChange(let range) = event { received.append(range) }
            }
            .store(in: &cancellables)

        view.setSelectedRange(NSRange(location: 0, length: 5))

        let expectation = expectation(description: "selectionDidChange delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(
            received.contains(NSRange(location: 0, length: 5)),
            "Setting selection should fan out a textSelectionDidChange event into the customer-supplied UnifiedEventSystem."
        )
        XCTAssertEqual(
            view.runtime.dependencies.eventBus.recentEvents { event in
                if case .textSelectionDidChange(let range) = event {
                    return range == NSRange(location: 0, length: 5)
                }
                return false
            }.count,
            1,
            "A selection change must enter the canonical bus exactly once."
        )
    }

    func testBecomeFirstResponderFansOutFocusEvent() throws {
        let (view, eventSystem, window) = try makeHostedView()
        defer { window.close() }

        // makeKeyAndOrderFront may have auto-promoted the text view to first
        // responder already. Drop the responder before attaching the sink so
        // we observe the next become transition cleanly.
        _ = window.makeFirstResponder(window.contentView)

        var becameCount = 0
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .didBecomeFirstResponder = event { becameCount += 1 }
            }
            .store(in: &cancellables)

        let priorBusEventCount = view.runtime.dependencies.eventBus.recentEvents { event in
            if case .didBecomeFirstResponder = event { return true }
            return false
        }.count
        let became = window.makeFirstResponder(view)
        XCTAssertTrue(became, "Window must be able to make the editor view first responder for this test to be meaningful.")

        XCTAssertEqual(becameCount, 1, "becomeFirstResponder() should fan out exactly one didBecomeFirstResponder event.")
        XCTAssertEqual(
            view.runtime.dependencies.eventBus.recentEvents { event in
                if case .didBecomeFirstResponder = event { return true }
                return false
            }.count,
            priorBusEventCount + 1
        )
    }

    func testResignFirstResponderFansOutFocusEvent() throws {
        let (view, eventSystem, window) = try makeHostedView()
        defer { window.close() }

        var resignedCount = 0
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .didResignFirstResponder = event { resignedCount += 1 }
            }
            .store(in: &cancellables)

        _ = window.makeFirstResponder(view)
        // Move focus off — back to the window's contentView, then nil.
        _ = window.makeFirstResponder(window.contentView)

        XCTAssertEqual(resignedCount, 1, "Losing first-responder status should fan out exactly one didResignFirstResponder event.")
        XCTAssertEqual(
            view.runtime.dependencies.eventBus.recentEvents { event in
                if case .didResignFirstResponder = event { return true }
                return false
            }.count,
            1
        )
    }
}
#endif
