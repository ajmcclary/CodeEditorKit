#if canImport(UIKit)
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import UIKit
import XCTest

@MainActor
final class IOSCoordinatorMultiplexerTests: XCTestCase {
    func testCoordinatorTextChangeMirrorsBinding() throws {
        var bindingValue = "initial"
        var onTextChangeReceived: String?

        let binding = Binding<String>(
            get: { bindingValue },
            set: { bindingValue = $0 }
        )
        let coordinator = CodeEditorCoordinator(
            text: binding,
            onTextChange: { onTextChangeReceived = $0 },
            onSelectionChange: nil
        )

        let codeEditorView = CodeEditorView(frame: .zero)
        coordinator.setupTextViewDelegate(codeEditorView)

        // Mutate the text view's underlying text, then drive
        // textViewDidChangeText through the participant API. The
        // multiplexer would call this same method when AppKit/UIKit
        // fires textViewDidChange.
        codeEditorView.text = "hello"
        coordinator.textViewDidChangeText(codeEditorView)

        XCTAssertEqual(bindingValue, "hello", "Text binding must mirror textViewDidChangeText")
        XCTAssertEqual(onTextChangeReceived, "hello", "onTextChange callback must fire")
    }
}
#endif
