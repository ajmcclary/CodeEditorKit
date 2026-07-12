import CodeEditorConfiguration
import CodeEditorDiagnostics
@testable import CodeEditorView
import Foundation
import Testing

@Suite("EditorConfiguration.Performance unifiedPerformanceSystem")
struct EditorConfigPerformanceUnifiedSystemTests {
    @Test
    @MainActor
    func defaultsToNil() {
        let perf = EditorConfiguration.Performance()
        #expect(perf.unifiedPerformanceSystem == nil)
    }

    @Test
    @MainActor
    func canBeSet() {
        var perf = EditorConfiguration.Performance()
        let ups = UnifiedPerformanceSystem()
        perf.unifiedPerformanceSystem = ups
        #expect(perf.unifiedPerformanceSystem === ups)
    }

    @Test
    @MainActor
    func equatableIgnoresUnifiedPerformanceSystem() {
        var lhs = EditorConfiguration.Performance()
        var rhs = EditorConfiguration.Performance()
        lhs.unifiedPerformanceSystem = UnifiedPerformanceSystem()
        rhs.unifiedPerformanceSystem = nil
        #expect(lhs == rhs)
    }

    @Test
    @MainActor
    func codableRoundTripIgnoresUnifiedPerformanceSystem() throws {
        var perf = EditorConfiguration.Performance()
        perf.unifiedPerformanceSystem = UnifiedPerformanceSystem()
        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(EditorConfiguration.Performance.self, from: data)
        #expect(decoded.unifiedPerformanceSystem == nil)
    }
}
