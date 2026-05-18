import CodeEditorConfiguration
import CodeEditorLanguages
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorView
import Testing

/// Smoke tests for the sample's switcher catalogs. These guard against the
/// catalogs going empty (broken theme bundles, accidental
/// `Language.allCases` filtering) and document the shape the demo UI
/// depends on.
@MainActor
@Suite("Switcher catalogs")
struct SwitcherCatalogTests {
    // MARK: - PresetCatalog

    @Test("PresetCatalog exposes the eight documented presets in order")
    func presetCatalogShape() {
        let ids = PresetCatalog.all.map(\.id)
        #expect(ids == [
            "default",
            "minimal",
            "readOnly",
            "markdown",
            "presentation",
            "macOS",
            "iOS",
            "platformOptimized"
        ])
        #expect(PresetCatalog.default.id == "default")
    }

    @Test("PresetCatalog.apply preserves performance settings from current")
    func presetApplyKeepsPerformance() {
        var current = EditorConfiguration.default
        current.performance.maxVisibleLines = 7_777  // user-tuned sentinel

        let applied = PresetCatalog.apply(
            PresetCatalog.all.first { $0.id == "minimal" } ?? PresetCatalog.default,
            onto: current
        )

        #expect(applied.performance.maxVisibleLines == 7_777)
        // Display/behavior/layout should come from the preset, not `current`.
        #expect(applied.display == EditorConfiguration.minimal.display)
    }

    // MARK: - LanguageCatalog

    @Test("LanguageCatalog covers every Language case, sorted by display name")
    func languageCatalogCoversAllLanguages() {
        #expect(LanguageCatalog.all.count == Language.allCases.count)
        let names = LanguageCatalog.all.map(\.name)
        #expect(names == names.sorted())
        #expect(LanguageCatalog.default == .swift)
    }

    // MARK: - ThemeCatalog

    @Test("ThemeCatalog loads the bundled zed-trek family")
    func themeCatalogLoadsBundledFamily() {
        #expect(!ThemeCatalog.all.isEmpty)
        #expect(ThemeCatalog.all.contains { $0.name == ThemeCatalog.default.name })
    }

    @Test("ThemeCatalog.theme(named:) falls back to default on miss")
    func themeCatalogFallsBackOnMiss() {
        let miss = ThemeCatalog.theme(named: "definitely-not-a-real-theme")
        #expect(miss.name == ThemeCatalog.default.name)
    }
}
#endif
