import CodeEditorAnnotations
import CodeEditorPlatform
@testable import CodeEditorView
import DesignKitThemes
import DesignKitTokens
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("Annotation theme")
struct AnnotationThemeTests {
    @Test("AnnotationKind.color(in:) returns theme.style.status.error.base for .error")
    @MainActor
    func errorColor() {
        let theme = Theme.lcarsDark
        let color = AnnotationKind.error.color(in: theme)
        #expect(color == PlatformColor(tokens: theme.style.status.error.base))
    }

    @Test("AnnotationKind.color(in:) returns theme.style.status.warning.base for .warning")
    @MainActor
    func warningColor() {
        let theme = Theme.lcarsDark
        let color = AnnotationKind.warning.color(in: theme)
        #expect(color == PlatformColor(tokens: theme.style.status.warning.base))
    }

    @Test("AnnotationKind.color(in:) maps fixme to status.warning or status.conflict")
    @MainActor
    func fixmeColor() {
        let theme = Theme.lcarsDark
        let color = AnnotationKind.fixme.color(in: theme)
        let warning = PlatformColor(tokens: theme.style.status.warning.base)
        let conflict = PlatformColor(tokens: theme.style.status.conflict.base)
        #expect(color == warning || color == conflict)
    }

    @Test("AnnotationKind.color(in:) maps info/note/todo to status.info")
    @MainActor
    func infoFamilyColors() {
        let theme = Theme.lcarsDark
        let infoExpected = PlatformColor(tokens: theme.style.status.info.base)
        #expect(AnnotationKind.info.color(in: theme) == infoExpected)
        #expect(AnnotationKind.note.color(in: theme) == infoExpected)
        #expect(AnnotationKind.todo.color(in: theme) == infoExpected)
    }

    @Test("AnnotationsContentView records the applied theme and is equality-gated")
    @MainActor
    func annotationsContentViewStoresTheme() {
        let view = AnnotationsContentView(frame: .zero)
        #expect(view.appliedTheme == nil)
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }

    @Test("AnnotationView records the applied theme and refreshes its badge color")
    @MainActor
    func annotationViewAppliesTheme() {
        let annotation = MessageLineAnnotation(
            id: "id-1",
            message: AttributedString("Test"),
            kind: .error,
            location: TestTextLocation()
        )
        let view = AnnotationView(annotation: annotation, frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
        #expect(view.themedBadgeColor == AnnotationKind.error.color(in: .lcarsDark))
    }
}

/// Minimal `NSTextLocation` stub for instantiating annotations in tests.
private final class TestTextLocation: NSObject, NSTextLocation {
    func compare(_: any NSTextLocation) -> ComparisonResult { .orderedSame }
}
