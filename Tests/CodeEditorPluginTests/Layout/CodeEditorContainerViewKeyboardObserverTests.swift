#if canImport(UIKit)
@testable import CodeEditorPlugin
import Foundation
import XCTest

/// Regression coverage for the block-observer-token leak in
/// `CodeEditorContainerView+Keyboard.setupKeyboardObservers()`. The old code
/// installed two block-based `NotificationCenter` observers
/// (keyboardWillShow / keyboardWillHide) and stored the returned tokens in
/// `keyboardObservers`, but `cleanupKeyboardObservers()` was never invoked —
/// `deinit` called `removeObserver(self)`, which doesn't reach block
/// observers. Same shape as the minimap leak fixed in commit ad23ccb9.
@MainActor
final class CodeEditorContainerViewKeyboardObserverTests: XCTestCase {
    func testSetupKeyboardObserversStoresTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        XCTAssertEqual(
            container.keyboardObservers.count,
            2,
            "setupKeyboardObservers() must capture both block observer tokens (willShow + willHide)"
        )
    }

    func testCleanupKeyboardObserversRemovesAllTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        XCTAssertFalse(container.keyboardObservers.isEmpty, "Precondition: setup registered observers")

        container.cleanupKeyboardObservers()
        XCTAssertTrue(
            container.keyboardObservers.isEmpty,
            "cleanupKeyboardObservers() must drop every stored token"
        )
    }

    func testReRunningSetupKeyboardObserversDoesNotAccumulateTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let initialCount = container.keyboardObservers.count
        XCTAssertGreaterThan(initialCount, 0)

        container.setupKeyboardObservers()
        XCTAssertEqual(
            container.keyboardObservers.count,
            initialCount,
            "Re-running setupKeyboardObservers() must clear previous tokens before re-installing — without that guard a second setup orphans the old tokens"
        )
    }

    func testContainerDeallocationFiresKeyboardCleanup() {
        weak var weakContainer: CodeEditorContainerView?
        autoreleasepool {
            let container = CodeEditorContainerView(
                frame: CGRect(x: 0, y: 0, width: 400, height: 300)
            )
            weakContainer = container
            XCTAssertFalse(container.keyboardObservers.isEmpty)
        }
        XCTAssertNil(
            weakContainer,
            "Container must deallocate — keyboard observers' [weak self] closures must not retain it"
        )
    }
}
#endif
