@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing

@Suite("ThemeableUIComponent — protocol over the editor's Theme value type")
struct ThemeableUIComponentTests {
    @Test("GutterView conforms to ThemeableUIComponent (Theme is the editor's value type)")
    @MainActor
    func gutterViewConformance() {
        let view: any ThemeableUIComponent = GutterView()
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
    }

    @Test("LineHighlightView conforms to ThemeableUIComponent")
    @MainActor
    func lineHighlightViewConformance() {
        let view: any ThemeableUIComponent = LineHighlightView()
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
    }

    @Test("InsertionPointView conforms to ThemeableUIComponent")
    @MainActor
    func insertionPointViewConformance() {
        let view: any ThemeableUIComponent = InsertionPointView()
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
    }

    @Test("AnnotationsContentView conforms to ThemeableUIComponent")
    @MainActor
    func annotationsContentViewConformance() {
        let view: any ThemeableUIComponent = AnnotationsContentView(frame: .zero)
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == Theme.lcarsDark)
    }
}
