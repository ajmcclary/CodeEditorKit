#if canImport(AppKit)
import AppKit
import Combine
import XCTest
@testable import CodeEditorPlugin

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
    }

    func testSelectionDidChangeFansOutToEventSystem() throws {
        let (view, eventSystem, window) = try makeHostedView(text: "hello world")
        defer { window.close() }

        var received: [NSRange] = []
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .textSelectionDidChange(let r) = event { received.append(r) }
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
    }
}
#endif
