import CodeEditorPlatform
import Dependencies
import Foundation

// MARK: - Dependency Factories

enum CodeEditorDependencies {
    @MainActor
    static func makeMemoryMonitor() -> MemoryMonitor {
        @Dependency(\.codeEditorMemoryMonitor) var factory
        return factory()
    }

    @MainActor
    static func makePlatformCapabilities() -> PlatformCapabilities {
        @Dependency(\.codeEditorPlatformCapabilities) var factory
        return factory()
    }

    @MainActor
    static func makePlatformServiceLayer() -> PlatformServiceLayer {
        @Dependency(\.codeEditorPlatformServiceLayer) var factory
        return factory()
    }

    @MainActor
    static func makePlatformDeviceService() -> PlatformDeviceService {
        @Dependency(\.codeEditorPlatformDeviceService) var factory
        return factory()
    }

    @MainActor
    static func makeLanguageMetadataRegistry() -> LanguageMetadataRegistry {
        @Dependency(\.codeEditorLanguageMetadataRegistry) var factory
        return factory()
    }

    @MainActor
    static func makeUnifiedPerformanceSystem() -> UnifiedPerformanceSystem {
        @Dependency(\.codeEditorUnifiedPerformanceSystem) var factory
        return factory()
    }

    static func makeParagraphStyleCache() -> ParagraphStyleCache {
        @Dependency(\.codeEditorParagraphStyleCache) var factory
        return factory()
    }

    static func makeProductionPerformanceMetrics() -> ProductionPerformanceMetrics {
        @Dependency(\.codeEditorProductionPerformanceMetrics) var factory
        return factory()
    }
}

private enum MemoryMonitorKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> MemoryMonitor {
        { MemoryMonitor() }
    }

    static var testValue: @MainActor @Sendable () -> MemoryMonitor {
        { MemoryMonitor() }
    }
}

private enum PlatformCapabilitiesKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> PlatformCapabilities {
        { PlatformCapabilities() }
    }

    static var testValue: @MainActor @Sendable () -> PlatformCapabilities {
        { PlatformCapabilities() }
    }
}

private enum PlatformServiceLayerKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> PlatformServiceLayer {
        { PlatformServiceLayer() }
    }

    static var testValue: @MainActor @Sendable () -> PlatformServiceLayer {
        { PlatformServiceLayer() }
    }
}

private enum PlatformDeviceServiceKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> PlatformDeviceService {
        { PlatformDeviceService() }
    }

    static var testValue: @MainActor @Sendable () -> PlatformDeviceService {
        { PlatformDeviceService() }
    }
}

private enum LanguageMetadataRegistryKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> LanguageMetadataRegistry {
        { LanguageMetadataRegistry() }
    }

    static var testValue: @MainActor @Sendable () -> LanguageMetadataRegistry {
        { LanguageMetadataRegistry() }
    }
}

private enum UnifiedPerformanceSystemKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> UnifiedPerformanceSystem {
        { UnifiedPerformanceSystem() }
    }

    static var testValue: @MainActor @Sendable () -> UnifiedPerformanceSystem {
        { UnifiedPerformanceSystem() }
    }
}

private enum ParagraphStyleCacheKey: DependencyKey {
    static var liveValue: @Sendable () -> ParagraphStyleCache {
        { ParagraphStyleCache() }
    }

    static var testValue: @Sendable () -> ParagraphStyleCache {
        { ParagraphStyleCache() }
    }
}

private enum ProductionPerformanceMetricsKey: DependencyKey {
    static var liveValue: @Sendable () -> ProductionPerformanceMetrics {
        { ProductionPerformanceMetrics() }
    }

    static var testValue: @Sendable () -> ProductionPerformanceMetrics {
        { ProductionPerformanceMetrics() }
    }
}

extension DependencyValues {
    /// Factory used to create memory monitors for editor instances.
    public var codeEditorMemoryMonitor: @MainActor @Sendable () -> MemoryMonitor {
        get { self[MemoryMonitorKey.self] }
        set { self[MemoryMonitorKey.self] = newValue }
    }

    /// Factory used to create platform capability detectors.
    public var codeEditorPlatformCapabilities: @MainActor @Sendable () -> PlatformCapabilities {
        get { self[PlatformCapabilitiesKey.self] }
        set { self[PlatformCapabilitiesKey.self] = newValue }
    }

    /// Factory used to create platform service layers.
    public var codeEditorPlatformServiceLayer: @MainActor @Sendable () -> PlatformServiceLayer {
        get { self[PlatformServiceLayerKey.self] }
        set { self[PlatformServiceLayerKey.self] = newValue }
    }

    /// Factory used to create platform device services.
    public var codeEditorPlatformDeviceService: @MainActor @Sendable () -> PlatformDeviceService {
        get { self[PlatformDeviceServiceKey.self] }
        set { self[PlatformDeviceServiceKey.self] = newValue }
    }

    /// Factory used to create language metadata registries.
    public var codeEditorLanguageMetadataRegistry: @MainActor @Sendable () -> LanguageMetadataRegistry {
        get { self[LanguageMetadataRegistryKey.self] }
        set { self[LanguageMetadataRegistryKey.self] = newValue }
    }

    /// Factory used to create unified performance systems.
    public var codeEditorUnifiedPerformanceSystem: @MainActor @Sendable () -> UnifiedPerformanceSystem {
        get { self[UnifiedPerformanceSystemKey.self] }
        set { self[UnifiedPerformanceSystemKey.self] = newValue }
    }

    /// Factory used to create paragraph style caches.
    public var codeEditorParagraphStyleCache: @Sendable () -> ParagraphStyleCache {
        get { self[ParagraphStyleCacheKey.self] }
        set { self[ParagraphStyleCacheKey.self] = newValue }
    }

    /// Factory used to create production performance metric recorders.
    public var codeEditorProductionPerformanceMetrics: @Sendable () -> ProductionPerformanceMetrics {
        get { self[ProductionPerformanceMetricsKey.self] }
        set { self[ProductionPerformanceMetricsKey.self] = newValue }
    }
}
