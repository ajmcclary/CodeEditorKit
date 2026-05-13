import SwiftUI

#if canImport(AppKit)
@preconcurrency import AppKit
#elseif canImport(UIKit)
@preconcurrency import UIKit
#endif

@available(macOS 13.0, iOS 16.0, *)
@MainActor
protocol CodeEditorPlatformAdapter {
    func text(from textView: CodeEditorView) -> String
    func setText(_ text: String, in textView: CodeEditorView, preserveSelection: Bool)
    func applySystemEditorColors(to textView: CodeEditorView)
    func invalidateLayoutAndDisplay(for textView: CodeEditorView)
    func requestFocus(for view: PlatformView)
    func textChangeObservers(for textView: CodeEditorView, coordinator: CodeEditorBaseCoordinator) -> [NSObjectProtocol]
    func setupPlatformFeatures(container: CodeEditorContainerView, coordinator: CodeEditorBaseCoordinator)
}

@available(macOS 13.0, iOS 16.0, *)
enum CodeEditorPlatformAdapterFactory {
    static func make() -> any CodeEditorPlatformAdapter {
        #if canImport(AppKit)
        AppKitCodeEditorPlatformAdapter()
        #else
        UIKitCodeEditorPlatformAdapter()
        #endif
    }
}

#if canImport(AppKit)
@available(macOS 13.0, *)
@MainActor
struct AppKitCodeEditorPlatformAdapter: CodeEditorPlatformAdapter {
    func text(from textView: CodeEditorView) -> String {
        textView.string
    }

    func setText(_ text: String, in textView: CodeEditorView, preserveSelection _: Bool) {
        if textView.string != text {
            textView.string = text
        }
    }

    func applySystemEditorColors(to textView: CodeEditorView) {
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
    }

    func invalidateLayoutAndDisplay(for textView: CodeEditorView) {
        textView.needsLayout = true
        textView.needsDisplay = true
    }

    func requestFocus(for view: PlatformView) {
        guard let containerView = view as? CodeEditorContainerView else { return }
        // The view may not yet be in a window when we're invoked (SwiftUI's
        // `sizeThatFits` / first `updateNSView` can run before the view is
        // attached). Poll on the main actor — bounded — until the window
        // arrives, then promote the inner text view to first responder.
        Task { @MainActor in
            for _ in 0..<10 {
                if let window = containerView.window {
                    window.makeFirstResponder(containerView.textView)
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func textChangeObservers(for textView: CodeEditorView, coordinator: CodeEditorBaseCoordinator) -> [NSObjectProtocol] {
        let textChangeObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak coordinator, weak textView] _ in
            MainActor.assumeIsolated {
                guard let coordinator, let textView else { return }
                coordinator.handleTextChange(textView.string)
            }
        }

        let selectionChangeObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak coordinator, weak textView] _ in
            MainActor.assumeIsolated {
                guard let coordinator, let textView else { return }
                coordinator.handleSelectionChange(textView.selectedRange())
            }
        }

        return [textChangeObserver, selectionChangeObserver]
    }

    func setupPlatformFeatures(container _: CodeEditorContainerView, coordinator _: CodeEditorBaseCoordinator) {}
}
#endif

#if canImport(UIKit)
@available(iOS 16.0, *)
@MainActor
struct UIKitCodeEditorPlatformAdapter: CodeEditorPlatformAdapter {
    func text(from textView: CodeEditorView) -> String {
        textView.text ?? ""
    }

    func setText(_ text: String, in textView: CodeEditorView, preserveSelection: Bool) {
        let savedSelectedRange = textView.selectedRange
        guard textView.text != text else { return }

        textView.text = text

        if preserveSelection, savedSelectedRange.location <= TextRangeUtilities.utf16Length(of: textView.text ?? "") {
            textView.setSelectedRangeWithoutScrolling(savedSelectedRange)
        }
    }

    func applySystemEditorColors(to textView: CodeEditorView) {
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
    }

    func invalidateLayoutAndDisplay(for textView: CodeEditorView) {
        textView.setNeedsLayout()
        textView.setNeedsDisplay()
    }

    func requestFocus(for view: PlatformView) {
        guard let containerView = view as? CodeEditorContainerView else { return }
        Task { @MainActor in
            _ = containerView.textView.becomeFirstResponder()
        }
    }

    func textChangeObservers(for textView: CodeEditorView, coordinator: CodeEditorBaseCoordinator) -> [NSObjectProtocol] {
        let textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak coordinator, weak textView] _ in
            MainActor.assumeIsolated {
                guard let coordinator, let textView else { return }
                coordinator.handleTextChange(textView.text ?? "")
            }
        }

        let selectionChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak coordinator, weak textView] _ in
            MainActor.assumeIsolated {
                guard let coordinator, let textView else { return }
                coordinator.handleSelectionChange(textView.selectedRange)
            }
        }

        return [textChangeObserver, selectionChangeObserver]
    }

    func setupPlatformFeatures(container: CodeEditorContainerView, coordinator: CodeEditorBaseCoordinator) {
        guard let coordinator = coordinator as? CodeEditorCoordinator else { return }
        coordinator.setupTextViewDelegate(container.textView)
    }
}
#endif
