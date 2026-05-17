import CodeEditorConfiguration
import CodeEditorDiagnostics
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import SnapshotTesting
import XCTest

@MainActor
final class CodeEditorSnapshotTests: XCTestCase {
    func testCodeEditorRendersSwiftSnippet() {
        let size = CGSize(width: 480, height: 240)
        let container = CodeEditorContainerView(frame: CGRect(origin: .zero, size: size))
        container.appearance = NSAppearance(named: .aqua)

        var configuration = EditorConfiguration.minimal
        configuration.display.fontSize = 13
        configuration.display.isLineNumbersEnabled = true
        configuration.display.isSelectedLineHighlighted = false
        configuration.layout.gutterWidth = 44
        configuration.layout.wrapLines = false
        configuration.performance.useHardwareAcceleration = false

        container.configuration = configuration
        container.textView.language = .swift
        container.textView.text = """
        struct Greeting {
            let name: String

            func message() -> String {
                "Hello, \\(name)"
            }
        }
        """
        container.layoutSubtreeIfNeeded()
        container.displayIfNeeded()

        assertSnapshot(
            of: container,
            as: .image(precision: 0.99, perceptualPrecision: 0.99, size: size)
        )
    }
}
#endif
