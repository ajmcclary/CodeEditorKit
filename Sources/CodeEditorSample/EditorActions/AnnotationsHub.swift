import CodeEditorPlugin
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Sample-side `AnnotationsDataSource` that surfaces two kinds of
/// per-line markers:
///
/// 1. **Breakpoints** — toggled red `ERROR` badges that stand in for the
///    debugger gutter. The framework's `DebuggerIntegrationCore` is
///    internal, so the sample fakes the rendering through annotations.
/// 2. **Demo annotations** — TODO / FIXME / WARNING badges added by the
///    user through the command palette or knob buttons.
///
/// Both render through the framework's existing annotation gutter
/// (`AnnotationKind.infer(from:)` keys color off the `content` prefix —
/// hence the literal "ERROR" / "TODO" / etc. baked into the content
/// strings). The hub borrows the host's `EditorController` to translate
/// 1-based line numbers into `NSTextRange`s on demand.
@MainActor
@Observable
final class AnnotationsHub: @preconcurrency AnnotationsDataSource {
    /// Set of 1-based line numbers carrying a breakpoint marker.
    private(set) var breakpointLines: Set<Int> = []

    /// 1-based line number → demo annotation kind. One entry per line
    /// (re-adding a different kind overwrites).
    private(set) var demoAnnotations: [Int: AnnotationKind] = [:]

    /// Weak handle on the host's `EditorController`; needed to translate
    /// line numbers into `NSTextRange`s when vending annotations.
    @ObservationIgnored
    weak var controller: EditorController?

    init(controller: EditorController? = nil) {
        self.controller = controller
    }

    // MARK: - Breakpoints

    func toggleBreakpoint(at line: Int) {
        guard line >= 1 else { return }
        if breakpointLines.contains(line) {
            breakpointLines.remove(line)
        } else {
            breakpointLines.insert(line)
        }
        controller?.reloadAnnotations()
    }

    func clearAllBreakpoints() {
        breakpointLines.removeAll()
        controller?.reloadAnnotations()
    }

    // MARK: - Demo annotations

    func addDemoAnnotation(kind: AnnotationKind, at line: Int) {
        guard line >= 1 else { return }
        demoAnnotations[line] = kind
        controller?.reloadAnnotations()
    }

    func removeDemoAnnotation(at line: Int) {
        demoAnnotations.removeValue(forKey: line)
        controller?.reloadAnnotations()
    }

    func clearAllDemoAnnotations() {
        demoAnnotations.removeAll()
        controller?.reloadAnnotations()
    }

    // MARK: - AnnotationsDataSource

    func annotations(for textRange: NSTextRange) -> [Annotation] {
        let all = currentAnnotations()
        return all.filter { $0.range.intersects(textRange) }
    }

    var textViewAnnotations: [CodeEditorViewAnnotation] {
        currentAnnotations().map { annotation in
            CodeEditorViewAnnotation(
                location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }

    func textView(
        _: CodeEditorView,
        viewForLineAnnotation _: CodeEditorViewAnnotation,
        textLineFragment _: NSTextLineFragment,
        proposedViewFrame _: CGRect
    ) -> PlatformView? {
        // Default rendering — the framework's annotation badge picks the
        // color via `AnnotationKind.infer(from: content)`.
        nil
    }

    // MARK: - Internal builders

    private func currentAnnotations() -> [Annotation] {
        guard let controller else { return [] }
        var out: [Annotation] = []
        for line in breakpointLines.sorted() {
            guard let range = controller.textRange(forLine: line) else { continue }
            out.append(Annotation(
                range: range,
                content: "ERROR: breakpoint",
                id: "bp-\(line)"
            ))
        }
        for line in demoAnnotations.keys.sorted() {
            guard let kind = demoAnnotations[line],
                  let range = controller.textRange(forLine: line) else { continue }
            out.append(Annotation(
                range: range,
                content: "\(kind.rawValue): demo annotation",
                id: "demo-\(kind.rawValue)-\(line)"
            ))
        }
        return out
    }
}
