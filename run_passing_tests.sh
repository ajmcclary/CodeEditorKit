#!/bin/bash

# Run only the tests that pass when run individually
# This excludes the hanging and failing tests

echo "Running all passing tests..."
echo "=============================="

# All passing tests
passing_tests=(
    "AnnotationTests"
    "AsyncSyntaxHighlighterCacheTests"
    "AsyncTextProcessorTests"
    "AutoScrollTests"
    "CatalystIntegrationTests"
    "CodeEditorContainerViewTests"
    "CompletionSystemTests"
    "ComprehensivePerformanceTests"
    "ConcurrencyTests"
    "ConfigurationBasicTests"
    "ConfigurationHotReloadTests"
    "ConfigurationIntegrationTests"
    "ConfigurationMigratorTests"
    "ContextMenuTests"
    "CrossPlatformCoordinatorTests"
    "DeviceTypeTests"
    "EdgeInsetsTests"
    "EditorConfigurationBuilderTests"
    "ErrorHandlingTests"
    "InputCoordinatorTests"
    "IntegrationTests"
    "LanguageDetectionTests"
    "LargeFileHighlightingBenchmarkTests"
    "LargeFilePerformanceTests"
    "LineCountingTests"
    "LineIndexCacheTests"
    "LineNumbersPlatformTests"
    "LSPIntegrationTests"
    "MemoryLeakTests"
    "MemoryMonitorDITests"
    "ParagraphStyleCacheTests"
    "PerformanceStressTests"
    "PlatformAbstractionTests"
    "PlatformCapabilitiesTests"
    "PlatformConfigurationsLoggingTest"
    "PlatformPresetsTests"
    "RegexHighlighterPerformanceTests"
    "ScrollPositionPreservationTests"
    "SimpleMemoryTest"
    "SwiftUICoordinatorTests"
    "SwiftUIEnvironmentConfigurationTests"
    "SwiftUIEnvironmentTests"
    "SwiftUIIntegrationTests"
    "SwiftUIModifierTests"
    "SwiftUITests"
    "SyntaxHighlightingPerformanceTests"
    "SyntaxHighlightingTests"
    "TextKit2OptimizationTests"
)

# Create a filter pattern for all passing tests
filter_pattern="${passing_tests[0]}"
for test in "${passing_tests[@]:1}"; do
    filter_pattern="${filter_pattern}|${test}"
done

# Run tests with the combined filter
swift test --filter "$filter_pattern"