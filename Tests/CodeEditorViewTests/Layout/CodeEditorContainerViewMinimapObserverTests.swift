@testable import CodeEditorView
import Foundation
import XCTest

/// Regression coverage for the block-observer-token leak in
/// `CodeEditorContainerView+Minimap.setupMinimap()`. The old code
/// installed two (AppKit) or one (UIKit) block-based `NotificationCenter`
/// observer(s) and dropped the returned tokens; `deinit` only invoked
/// `removeObserver(self)`, which doesn't reach block observers, so they
/// leaked for the lifetime of the process.
@MainActor
final class CodeEditorContainerViewMinimapObserverTests: XCTestCase {
    func testSetupMinimapStoresObserverTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        XCTAssertEqual(
            container.minimapObservers.count,
            expectedObserverCount,
            "setupMinimap() must capture the block observer tokens it installs"
        )
    }

    func testCleanupMinimapObserversRemovesAllTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        XCTAssertFalse(container.minimapObservers.isEmpty, "Precondition: setup registered observers")

        container.cleanupMinimapObservers()
        XCTAssertTrue(
            container.minimapObservers.isEmpty,
            "cleanupMinimapObservers() must drop every stored token"
        )
    }

    func testReRunningSetupMinimapDoesNotAccumulateTokens() {
        let container = CodeEditorContainerView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let initialCount = container.minimapObservers.count
        XCTAssertGreaterThan(initialCount, 0)

        container.setupMinimap()
        XCTAssertEqual(
            container.minimapObservers.count,
            initialCount,
            "Re-running setupMinimap() must clear previous tokens before re-installing — without that guard a second setup orphans the old tokens"
        )
    }

    func testContainerDeallocationFiresMinimapCleanup() {
        weak var weakContainer: CodeEditorContainerView?
        autoreleasepool {
            let container = CodeEditorContainerView(
                frame: CGRect(x: 0, y: 0, width: 400, height: 300)
            )
            weakContainer = container
            XCTAssertFalse(container.minimapObservers.isEmpty)
        }
        XCTAssertNil(
            weakContainer,
            "Container must deallocate — minimap observers' [weak self] closures must not retain it"
        )
    }

    // MARK: - Helpers

    private var expectedObserverCount: Int {
        #if canImport(AppKit)
        return 2  // text didChange + bounds didChange
        #else
        return 1  // text didChange only; scroll handled via delegate
        #endif
    }
}
