#if canImport(AppKit)
import AppKit
import CodeEditorTheming

/// macOS gutter host. Attached as a floating subview of the scroll view;
/// owns the renderer, the bounds/text/selection observers, and fold-click
/// hit-testing. The cross-platform `GutterView` is the iOS-only host.
@MainActor
final class CodeEditorGutterView: NSView {
    weak var textView: CodeEditorView?
    let renderer = GutterViewRenderer()
    private(set) var lastActiveLineNumber: Int?

    /// The scroll view this gutter is attached to, if any. `addFloatingSubview`
    /// stashes the view in an internal AppKit container rather than the
    /// scroll view's direct subviews, so `superview` cannot be used as a
    /// reliable "am I attached?" signal — we track it explicitly instead.
    private(set) weak var attachedScrollView: NSScrollView?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("CodeEditorGutterView does not support NSCoder")
    }

    /// Attaches the gutter as a floating subview of `scrollView` and binds
    /// it to `textView`. Idempotent: re-attaching to the same scroll view
    /// is a no-op; re-attaching to a different scroll view tears down the
    /// previous attachment first.
    func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
        if attachedScrollView === scrollView, self.textView === textView { return }
        if attachedScrollView != nil { detach() }
        self.textView = textView
        attachedScrollView = scrollView
        scrollView.addFloatingSubview(self, for: .horizontal)
    }

    /// Removes the gutter from its scroll view.
    func detach() {
        removeFromSuperview()
        attachedScrollView = nil
        textView = nil
    }
}
#endif
