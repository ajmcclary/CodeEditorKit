import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Testing

@Suite("UnifiedPerformanceSystem non-throwing track")
struct UnifiedPerformanceSystemNonThrowingTrackTests {
    @Test
    @MainActor
    func trackNonThrowingRecordsOneMetric() async {
        let ups = UnifiedPerformanceSystem()
        let value = await ups.track(.syntaxHighlighting) {
            42
        }
        #expect(value == 42)
        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        #expect(analysis?.count == 1)
    }
}
