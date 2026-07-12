@testable import CodeEditorView
import Testing

@MainActor
@Suite("TextKit2 rendering metrics")
struct TextKit2RenderingMetricsTests {
    @Test("records only observed layout work")
    func observedLayout() {
        let metrics = TextKit2RenderingMetrics()

        #expect(metrics.layoutPassCount == 0)
        #expect(metrics.visibleFragmentCount == 0)

        metrics.recordLayoutPass(
            duration: .milliseconds(3),
            visibleFragmentCount: 8
        )

        #expect(metrics.layoutPassCount == 1)
        #expect(metrics.visibleFragmentCount == 8)
        #expect(metrics.latestLayoutDuration == .milliseconds(3))
        #expect(abs(metrics.averageLayoutTime - 0.003) < 0.000_001)
    }
}
