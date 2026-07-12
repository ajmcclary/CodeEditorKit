import CodeEditorDiagnostics
@testable import CodeEditorView
import Testing

@Suite("AsyncSyntaxHighlighter UnifiedPerformanceSystem instrumentation")
struct AsyncSyntaxHighlighterInstrumentationTests {
    @Test
    @MainActor
    func recordsSyntaxHighlightingMetricWhenSystemInjected() async {
        let ups = UnifiedPerformanceSystem()
        let memoryMonitor = MemoryMonitor()
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor, enablePeriodicOptimization: false)
        let editorView = CodeEditorView(frame: .zero, memoryMonitor: memoryMonitor)
        editorView.asyncHighlighter = highlighter
        editorView.configuration.performance.unifiedPerformanceSystem = ups

        editorView.text = "let x = 42\nfunc test() { print(x) }"
        editorView.language = .swift

        await highlighter.highlightImmediately(for: editorView, language: .swift)
        try? await Task.sleep(for: .milliseconds(20))

        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        #expect((analysis?.count ?? 0) >= 1)

        highlighter.cleanup()
    }

    @Test
    @MainActor
    func recordsNothingWhenSystemIsNil() async {
        let ups = UnifiedPerformanceSystem()
        let memoryMonitor = MemoryMonitor()
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor, enablePeriodicOptimization: false)
        let editorView = CodeEditorView(frame: .zero, memoryMonitor: memoryMonitor)
        editorView.asyncHighlighter = highlighter
        editorView.configuration.performance.unifiedPerformanceSystem = nil

        editorView.text = "let x = 42"
        editorView.language = .swift

        await highlighter.highlightImmediately(for: editorView, language: .swift)
        try? await Task.sleep(for: .milliseconds(20))

        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        // swiftlint:disable:next empty_count
        #expect(analysis == nil || analysis?.count == 0)

        highlighter.cleanup()
    }
}
