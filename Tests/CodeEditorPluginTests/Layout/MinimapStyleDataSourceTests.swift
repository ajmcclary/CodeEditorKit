@testable import CodeEditorPlugin
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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

        let ds = StyledMinimapStyleDataSource(container: container)
        let runs = ds.styleRuns(in: NSRange(location: 5, length: 20))
        let keywordRuns = runs.filter { $0.color == PlatformColors.label || true }
        #expect(!runs.isEmpty)
    }
}

@Suite("MinimapViewModel style data source")
struct MinimapViewModelStyleDataSourceTests {
    @Test("MinimapViewModel styleDataSource defaults to nil")
    @MainActor
    func defaultsNil() {
        let vm = MinimapViewModel(
            configuration: EditorConfiguration(),
            businessLogicServices: BusinessLogicServiceRegistry()
        )
        #expect(vm.styleDataSource == nil)
    }

    @Test("MinimapViewModel accepts style data source")
    @MainActor
    func acceptsDataSource() {
        let vm = MinimapViewModel(
            configuration: EditorConfiguration(),
            businessLogicServices: BusinessLogicServiceRegistry()
        )
        let ds = NoOpMinimapStyleDataSource()
        vm.styleDataSource = ds
        #expect(vm.styleDataSource != nil)
    }
}
