@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class InputCoordinatorTests: XCTestCase {
    // MARK: - Platform Input Event Tests

    func testKeyboardEventHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let keyEvent = PlatformInputEvent.keyDown(key: "a", modifiers: [])
        let handled = coordinator.handleInput(keyEvent, in: mockView)
        // Basic key input should not be handled by coordinator
        XCTAssertFalse(handled, "Basic key input should be passed through")
    }

    func testCommandKeyHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let cmdAEvent = PlatformInputEvent.keyDown(key: "a", modifiers: [.command])
        let handled = coordinator.handleInput(cmdAEvent, in: mockView)
        XCTAssertTrue(handled, "Command+A should be handled")
    }

    func testCopyPasteHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Test copy
        let cmdCEvent = PlatformInputEvent.keyDown(key: "c", modifiers: [.command])
        let copyHandled = coordinator.handleInput(cmdCEvent, in: mockView)
        XCTAssertTrue(copyHandled, "Command+C should be handled")

        // Test paste
        let cmdVEvent = PlatformInputEvent.keyDown(key: "v", modifiers: [.command])
        let pasteHandled = coordinator.handleInput(cmdVEvent, in: mockView)
        XCTAssertTrue(pasteHandled, "Command+V should be handled")

        // Test cut
        let cmdXEvent = PlatformInputEvent.keyDown(key: "x", modifiers: [.command])
        let cutHandled = coordinator.handleInput(cmdXEvent, in: mockView)
        XCTAssertTrue(cutHandled, "Command+X should be handled")
    }

    func testUndoRedoHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Test undo
        let cmdZEvent = PlatformInputEvent.keyDown(key: "z", modifiers: [.command])
        let undoHandled = coordinator.handleInput(cmdZEvent, in: mockView)
        XCTAssertTrue(undoHandled, "Command+Z should be handled")

        // Test redo
        let cmdShiftZEvent = PlatformInputEvent.keyDown(key: "z", modifiers: [.command, .shift])
        let redoHandled = coordinator.handleInput(cmdShiftZEvent, in: mockView)
        XCTAssertTrue(redoHandled, "Command+Shift+Z should be handled")
    }

    // MARK: - Touch Event Tests

    func testTouchEventHandling() {
        #if canImport(UIKit)
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let touchInfo = TouchInfo(
            location: CGPoint(x: 100, y: 100),
            previousLocation: CGPoint(x: 100, y: 100),
            timestamp: Date().timeIntervalSince1970,
            identifier: 1
        )
        let touchEvent = PlatformInputEvent.touch(touches: Set([touchInfo]), phase: .began)
        let handled = coordinator.handleInput(touchEvent, in: mockView)
        XCTAssertTrue(handled, "Touch events should be handled on iOS")
        #endif
    }

    // MARK: - Mouse Event Tests

    func testMouseEventHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let mouseDownEvent = PlatformInputEvent.mouse(location: CGPoint(x: 100, y: 100), type: .down)
        let handled = coordinator.handleInput(mouseDownEvent, in: mockView)
        XCTAssertTrue(handled, "Mouse down should be handled")
    }

    func testRightClickHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let rightClickEvent = PlatformInputEvent.mouse(location: CGPoint(x: 100, y: 100), type: .rightClick)
        let handled = coordinator.handleInput(rightClickEvent, in: mockView)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(handled, "Right click should be handled on macOS")
        #endif
    }

    // MARK: - Pencil Event Tests

    func testPencilEventHandling() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let pencilEvent = PlatformInputEvent.pencil(location: CGPoint(x: 100, y: 100), pressure: 0.5, azimuth: 0.0)
        let handled = coordinator.handleInput(pencilEvent, in: mockView)

        #if canImport(UIKit)
        let capabilities = PlatformCapabilities.shared
        if capabilities.supportsPencilInput {
            XCTAssertTrue(handled, "Pencil input should be handled on supported devices")
        } else {
            XCTAssertFalse(handled, "Pencil input should not be handled on unsupported devices")
        }
        #else
        XCTAssertFalse(handled, "Pencil input is not handled on macOS")
        #endif
    }

    // MARK: - Gesture Configuration Tests

    func testGestureConfiguration() {
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        coordinator.configureGestures(for: mockView)

        #if canImport(UIKit)
        let gestures = mockView.gestureRecognizers ?? []
        XCTAssertFalse(gestures.isEmpty, "Gestures should be configured on iOS")

        // Check for specific gesture types
        let hasTapGesture = gestures.contains { $0 is UITapGestureRecognizer }
        XCTAssertTrue(hasTapGesture, "Should have tap gesture")

        let hasLongPressGesture = gestures.contains { $0 is UILongPressGestureRecognizer }
        XCTAssertTrue(hasLongPressGesture, "Should have long press gesture")

        let hasPanGesture = gestures.contains { $0 is UIPanGestureRecognizer }
        XCTAssertTrue(hasPanGesture, "Should have pan gesture")
        #endif
    }

    func testGestureRemoval() {
        #if canImport(UIKit)
        let coordinator = InputCoordinator()
        let mockView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // First configure gestures
        coordinator.configureGestures(for: mockView)
        XCTAssertNotNil(mockView.gestureRecognizers, "Should have gestures")
        XCTAssertFalse(mockView.gestureRecognizers?.isEmpty ?? true, "Should have gestures configured")

        // Then remove them
        coordinator.removeGestures(from: mockView)
        XCTAssertTrue(mockView.gestureRecognizers?.isEmpty ?? true, "All gestures should be removed")
        #endif
    }

    // MARK: - Convenience Method Tests

    func testConvenienceEventCreation() {
        // Test keyboard event creation
        let keyEvent = InputCoordinator.keyboardEvent(key: "a", modifiers: [.command])
        if case let .keyDown(key, modifiers) = keyEvent {
            XCTAssertEqual(key, "a")
            XCTAssertTrue(modifiers.contains(.command))
        } else {
            XCTFail("Should create keyboard event")
        }

        // Test mouse event creation
        let mouseEvent = InputCoordinator.mouseEvent(at: CGPoint(x: 10, y: 20), type: .down)
        if case let .mouse(location, type) = mouseEvent {
            XCTAssertEqual(location.x, 10)
            XCTAssertEqual(location.y, 20)
            XCTAssertEqual(type, .down)
        } else {
            XCTFail("Should create mouse event")
        }

        // Test touch event creation
        let touchInfo = TouchInfo(location: CGPoint(x: 50, y: 50), previousLocation: CGPoint(x: 40, y: 40), timestamp: Date().timeIntervalSinceReferenceDate)
        let touchEvent = InputCoordinator.touchEvent(touches: Set([touchInfo]), phase: .began)
        if case let .touch(_, phase) = touchEvent {
            XCTAssertEqual(phase, PlatformTouchPhase.began)
        } else {
            XCTFail("Should create touch event")
        }

        // Test pencil event creation
        let pencilEvent = InputCoordinator.pencilEvent(at: CGPoint(x: 30, y: 40), pressure: 0.7, azimuth: 1.5)
        if case let .pencil(location, pressure, azimuth) = pencilEvent {
            XCTAssertEqual(location.x, 30)
            XCTAssertEqual(location.y, 40)
            XCTAssertEqual(pressure, 0.7)
            XCTAssertEqual(azimuth, 1.5)
        } else {
            XCTFail("Should create pencil event")
        }
    }
}
