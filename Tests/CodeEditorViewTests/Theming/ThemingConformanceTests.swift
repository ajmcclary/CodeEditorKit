import DesignKitThemes
import Foundation
import Testing

/// Compile-time conformance asserts. If any theme value type loses
/// Sendable or Hashable, this file stops compiling. (Codable was retired
/// with the DesignKit migration — themes are compile-time Swift values.)
@Suite("Theming conformance audit")
struct ThemingConformanceTests {
    private static func requireValueConformance<T>(_ type: T.Type)
    where T: Sendable & Hashable {
        _ = String(describing: type)
    }

    @Test("theme model types conform to Sendable and Hashable")
    func auditModelTypes() {
        Self.requireValueConformance(Theme.self)
        Self.requireValueConformance(Theme.Appearance.self)
        Self.requireValueConformance(Theme.Family.self)
        Self.requireValueConformance(ThemeStyle.self)
        Self.requireValueConformance(EditorColors.self)
        Self.requireValueConformance(ChromeColors.self)
        Self.requireValueConformance(ElementStates.self)
        Self.requireValueConformance(ElementStates.States.self)
        Self.requireValueConformance(BorderColors.self)
        Self.requireValueConformance(TextLevels.self)
        Self.requireValueConformance(IconLevels.self)
        Self.requireValueConformance(StatusPalette.self)
        Self.requireValueConformance(StatusPalette.Status.self)
        Self.requireValueConformance(VCSPalette.self)
        Self.requireValueConformance(VCSPalette.VCS.self)
        Self.requireValueConformance(ScrollbarColors.self)
        Self.requireValueConformance(SearchColors.self)
        Self.requireValueConformance(PredictiveColors.self)
        Self.requireValueConformance(HintColors.self)
        Self.requireValueConformance(Player.self)
        Self.requireValueConformance(SyntaxStyle.self)
        Self.requireValueConformance(SyntaxStyle.FontStyle.self)
        Self.requireValueConformance(TerminalColors.self)
        Self.requireValueConformance(TerminalColors.ANSI.self)
        Self.requireValueConformance(GlassStyle.self)
        Self.requireValueConformance(GlassStyle.Glass.self)
        Self.requireValueConformance(GlassStyle.Shadow.self)
        Self.requireValueConformance(GlassStyle.Shadows.self)
        Self.requireValueConformance(GlassStyle.Field.self)
        Self.requireValueConformance(AccessibilityPreferences.self)
    }
}
