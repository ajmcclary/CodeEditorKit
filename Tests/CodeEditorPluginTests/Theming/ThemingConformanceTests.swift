@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing

/// Compile-time conformance asserts. If any theme value type loses
/// Sendable, Hashable, or Codable, this file stops compiling.
/// `ThemeWarning` is a runtime diagnostic, not a serialization target,
/// so its conformance is a lighter `Sendable & Hashable`.
@Suite("Theming conformance audit")
struct ThemingConformanceTests {
    private static func requireFullConformance<T>(_ type: T.Type)
    where T: Sendable & Hashable & Codable {
        _ = String(describing: type)
    }

    private static func requireDiagnosticConformance<T>(_ type: T.Type)
    where T: Sendable & Hashable {
        _ = String(describing: type)
    }

    @Test("public Theming model types conform to Sendable, Hashable, Codable")
    func auditModelTypes() {
        Self.requireFullConformance(Theme.self)
        Self.requireFullConformance(Theme.Appearance.self)
        Self.requireFullConformance(ThemeFamily.self)
        Self.requireFullConformance(ThemeStyle.self)
        Self.requireFullConformance(EditorColors.self)
        Self.requireFullConformance(ChromeColors.self)
        Self.requireFullConformance(ElementStates.self)
        Self.requireFullConformance(ElementStates.States.self)
        Self.requireFullConformance(BorderColors.self)
        Self.requireFullConformance(TextLevels.self)
        Self.requireFullConformance(IconLevels.self)
        Self.requireFullConformance(StatusPalette.self)
        Self.requireFullConformance(StatusPalette.Status.self)
        Self.requireFullConformance(VCSPalette.self)
        Self.requireFullConformance(VCSPalette.VCS.self)
        Self.requireFullConformance(ScrollbarColors.self)
        Self.requireFullConformance(SearchColors.self)
        Self.requireFullConformance(PredictiveColors.self)
        Self.requireFullConformance(HintColors.self)
        Self.requireFullConformance(Player.self)
        Self.requireFullConformance(SyntaxStyle.self)
        Self.requireFullConformance(SyntaxStyle.FontStyle.self)
        Self.requireFullConformance(TerminalColors.self)
        Self.requireFullConformance(TerminalColors.ANSI.self)
        Self.requireFullConformance(PlatformExtension.self)
        Self.requireFullConformance(PlatformExtension.Glass.self)
        Self.requireFullConformance(PlatformExtension.Shadow.self)
        Self.requireFullConformance(PlatformExtension.Shadows.self)
        Self.requireFullConformance(PlatformExtension.Field.self)
    }

    @Test("ThemeWarning is Sendable + Hashable")
    func auditDiagnosticTypes() {
        Self.requireDiagnosticConformance(ThemeWarning.self)
        Self.requireDiagnosticConformance(ThemeWarning.Kind.self)
    }
}
