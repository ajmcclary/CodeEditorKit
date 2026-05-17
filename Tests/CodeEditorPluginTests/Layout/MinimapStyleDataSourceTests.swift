import CodeEditorConfiguration
import CodeEditorPlatform
@testable import CodeEditorPlugin
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
private final class FixedMinimapStyleDataSource: MinimapStyleDataSource {
    let runs: [MinimapStyleRun]

    init(runs: [MinimapStyleRun]) {
        self.runs = runs
    }

    func styleRuns(in _: NSRange) -> [MinimapStyleRun] {
        runs
    }
}

@Suite("MinimapStyleDataSource")
struct MinimapStyleDataSourceTests {
    @Test("MinimapStyleRun is Equatable")
    func runEquatable() {
        let run1 = MinimapStyleRun(range: NSRange(location: 0, length: 5), color: .red)
        let run2 = MinimapStyleRun(range: NSRange(location: 0, length: 5), color: .red)
        let run3 = MinimapStyleRun(range: NSRange(location: 1, length: 5), color: .red)
        #expect(run1 == run2)
        #expect(run1 != run3)
    }

    @Test("NoOpMinimapStyleDataSource returns empty")
    @MainActor
    func noOpEmpty() {
        let ds = NoOpMinimapStyleDataSource()
        let runs = ds.styleRuns(in: NSRange(location: 0, length: 100))
        #expect(runs.isEmpty)
    }

    @Test("StyledMinimapStyleDataSource returns runs from container")
    @MainActor
    func styledReturnsRuns() {
        let container = StyledRangeContainer(documentLength: 100)
        let id = container.registerProvider(priority: 0)
        let token = HighlightedToken(
            range: NSRange(location: 10, length: 5),
            type: .keyword,
            text: "hello"
        )
        container.applyHighlightResult(providerID: id, highlights: [token], range: NSRange(location: 0, length: 100))

        let expectedColor = PlatformColors.systemBlue
        let ds = StyledMinimapStyleDataSource(container: container) { capture in
            capture == "keyword" ? expectedColor : PlatformColors.label
        }
        let runs = ds.styleRuns(in: NSRange(location: 5, length: 20))
        #expect(runs == [
            MinimapStyleRun(range: NSRange(location: 10, length: 5), color: expectedColor)
        ])
    }

    @Test("MinimapData carries style runs")
    func minimapDataCarriesStyleRuns() {
        let styleRun = MinimapStyleRun(
            range: NSRange(location: 4, length: 3),
            color: PlatformColors.systemGreen
        )
        let data = MinimapData(
            totalLines: 2,
            visibleLineRange: 0..<1,
            displayLines: ["let x = 1"],
            displayStartLine: 0,
            characterWidth: 2,
            lineHeight: 4,
            styleRuns: [styleRun]
        )

        #expect(data.styleRuns == [styleRun])
    }

    @Test("MinimapDataProvider emits style runs from its data source")
    @MainActor
    func dataProviderEmitsStyleRuns() {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif
        let styleRun = MinimapStyleRun(
            range: NSRange(location: 0, length: 3),
            color: PlatformColors.systemBlue
        )
        let provider = MinimapDataProvider(textView: textView)
        provider.styleDataSource = FixedMinimapStyleDataSource(runs: [styleRun])

        let data = provider.generateData()

        #expect(data?.styleRuns == [styleRun])
    }
}

@Suite("MinimapViewModel style data source")
struct MinimapViewModelStyleDataSourceTests {
    @Test("MinimapViewModel styleDataSource defaults to nil")
    @MainActor
    func defaultsNil() {
        let vm = MinimapViewModel(
            configuration: EditorConfiguration(),
            featureDependencies: EditorFeatureRuntimeDependencies()
        )
        #expect(vm.styleDataSource == nil)
    }

    @Test("MinimapViewModel accepts style data source")
    @MainActor
    func acceptsDataSource() {
        let vm = MinimapViewModel(
            configuration: EditorConfiguration(),
            featureDependencies: EditorFeatureRuntimeDependencies()
        )
        let ds = NoOpMinimapStyleDataSource()
        vm.styleDataSource = ds
        #expect(vm.styleDataSource != nil)
    }
}
