import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel
@testable import CodeEditorView
import Testing

@MainActor
@Suite("EditorRuntime state preservation")
struct EditorRuntimeStatePreservationTests {
    @Test("infrastructure update preserves feature dependency identity")
    func infrastructureUpdatePreservesFeatureDependencies() {
        let features = EditorFeatureRuntimeDependencies()
        let runtime = EditorRuntime(dependencies: makeDependencies())
        runtime.replace(featureDependencies: features)

        runtime.update(dependencies: makeDependencies())

        #expect(runtime.featureDependencies === features)
    }

    private func makeDependencies() -> EditorRuntimeDependencies {
        EditorRuntimeDependencies(
            memoryMonitor: MemoryMonitor(),
            actorCoordinator: ActorCoordinator.create(),
            platformCapabilities: PlatformCapabilities(),
            unifiedPerformanceSystem: UnifiedPerformanceSystem(),
            paragraphStyleCache: ParagraphStyleCache(),
            languageMetadataRegistry: LanguageMetadataRegistry(),
            platformServiceLayer: PlatformServiceLayer(),
            platformDeviceService: PlatformDeviceService()
        )
    }
}
