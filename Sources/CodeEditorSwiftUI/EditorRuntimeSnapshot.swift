import CodeEditorView
import Foundation

@MainActor
struct EditorRuntimeSnapshot: Equatable {
    let workspaceRoot: URL?
    let eventSystem: ObjectIdentifier?
    let memoryMonitor: ObjectIdentifier
    let actorCoordinator: ObjectIdentifier
    let platformCapabilities: ObjectIdentifier
    let unifiedPerformanceSystem: ObjectIdentifier
    let paragraphStyleCache: ObjectIdentifier
    let languageMetadataRegistry: ObjectIdentifier
    let platformServiceLayer: ObjectIdentifier
    let platformDeviceService: ObjectIdentifier

    init(_ dependencies: EditorRuntimeDependencies) {
        workspaceRoot = dependencies.workspaceRoot
        eventSystem = dependencies.eventSystem.map(ObjectIdentifier.init)
        memoryMonitor = ObjectIdentifier(dependencies.memoryMonitor)
        actorCoordinator = ObjectIdentifier(dependencies.actorCoordinator)
        platformCapabilities = ObjectIdentifier(dependencies.platformCapabilities)
        unifiedPerformanceSystem = ObjectIdentifier(dependencies.unifiedPerformanceSystem)
        paragraphStyleCache = ObjectIdentifier(dependencies.paragraphStyleCache)
        languageMetadataRegistry = ObjectIdentifier(dependencies.languageMetadataRegistry)
        platformServiceLayer = ObjectIdentifier(dependencies.platformServiceLayer)
        platformDeviceService = ObjectIdentifier(dependencies.platformDeviceService)
    }
}
