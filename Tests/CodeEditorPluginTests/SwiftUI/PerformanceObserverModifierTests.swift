//
//  PerformanceObserverModifierTests.swift
//  CodeEditorPluginTests
//

import CodeEditorConfiguration
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorView
import SwiftUI
import XCTest

final class PerformanceObserverModifierTests: XCTestCase {
    @MainActor
    func testMakeEffectiveConfigurationInjectsObservedSystem() {
        let observation = PerformanceObservation()
        let env = CodeEditorEnvironment(performanceObservation: observation)

        let effective = CodeEditor.makeEffectiveConfiguration(from: env)

        XCTAssertIdentical(
            effective.performance.unifiedPerformanceSystem,
            observation.system,
            "Observation system should be injected into the effective configuration."
        )
    }

    @MainActor
    func testMakeEffectiveConfigurationNoObservationLeavesConfigUntouched() {
        let env = CodeEditorEnvironment()
        let effective = CodeEditor.makeEffectiveConfiguration(from: env)
        XCTAssertNil(effective.performance.unifiedPerformanceSystem)
    }

    @MainActor
    func testMakeEffectiveConfigurationObservationWinsOverDirectConfigInjection() {
        let systemA = UnifiedPerformanceSystem()
        var configuration = EditorConfiguration()
        configuration.performance.unifiedPerformanceSystem = systemA

        let observation = PerformanceObservation(system: UnifiedPerformanceSystem())
        let env = CodeEditorEnvironment(
            configuration: configuration,
            performanceObservation: observation
        )

        let effective = CodeEditor.makeEffectiveConfiguration(from: env)

        XCTAssertIdentical(
            effective.performance.unifiedPerformanceSystem,
            observation.system,
            "Modifier-supplied observation should win over direct config injection."
        )
        XCTAssertNotIdentical(
            effective.performance.unifiedPerformanceSystem,
            systemA,
            "Direct config injection should be overridden when an observation is present."
        )
    }
}
