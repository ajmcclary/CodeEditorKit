@testable import CodeEditorPlugin
import Testing

@Suite("GutterViewRenderer active line color")
@MainActor
struct GutterViewRendererActiveLineTests {
    @Test("Active line resolves to themedActiveLineNumberColor.")
    func activeLineUsesActiveColor() async throws {
        let renderer = GutterViewRenderer()
        renderer.apply(theme: .lcarsDark)

        let active = renderer.color(forLineNumber: 2, activeLineNumber: 2)
        let inactive = renderer.color(forLineNumber: 1, activeLineNumber: 2)

        #expect(active == renderer.themedActiveLineNumberColor)
        #expect(inactive == renderer.themedLineNumberColor)
    }

    @Test("Nil activeLineNumber resolves every line to the inactive color.")
    func nilActiveRendersAllInactive() async throws {
        let renderer = GutterViewRenderer()
        renderer.apply(theme: .lcarsDark)

        let color = renderer.color(forLineNumber: 2, activeLineNumber: nil)

        #expect(color == renderer.themedLineNumberColor)
    }

    @Test("apply(theme:) installs distinct active and inactive colors from the theme.")
    func applyThemeInstallsBothColors() async throws {
        let renderer = GutterViewRenderer()
        renderer.apply(theme: .lcarsDark)

        #expect(renderer.themedLineNumberColor.cgColor.alpha > 0)
        #expect(renderer.themedActiveLineNumberColor.cgColor.alpha > 0)
    }
}
