import CodeEditorDiagnostics
import CodeEditorPlugin
import SwiftUI

struct PerformanceKnobsSection: View {
    @Bindable var configuration: ConfigurationModel
    @State private var expanded: Bool = false
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Performance",
            icon: "gauge.with.dots.needle.bottom.50percent",
            accentIndex: 3,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                limitsSection
                strategySection
                debounceSection
                iOSSection
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var limitsSection: some View {
        KnobSubsection(title: "Limits")
        StepperRow(
            label: "maxSyntaxHighlightingLength",
            value: $configuration.current.performance.maxSyntaxHighlightingLength,
            range: 1_024...10_485_760,
            step: 1_024
        )
        StepperRow(
            label: "maxVisibleLines",
            value: $configuration.current.performance.maxVisibleLines,
            range: 1...100_000,
            step: 100
        )
        StepperRow(
            label: "maxFileSize",
            value: $configuration.current.performance.maxFileSize,
            range: 0...100_000_000,
            step: 1_024
        )
        StepperRow(
            label: "maxEventsPerSecond",
            value: $configuration.current.performance.maxEventsPerSecond,
            range: 1...240
        )
    }

    @ViewBuilder
    private var strategySection: some View {
        KnobSubsection(title: "Strategy")
        ToggleRow(
            label: "useHardwareAcceleration",
            value: $configuration.current.performance.useHardwareAcceleration
        )
        ToggleRow(label: "smoothScrolling", value: $configuration.current.performance.smoothScrolling)
        ToggleRow(
            label: "animateCodeFolding (perf)",
            value: $configuration.current.performance.animateCodeFolding
        )
        ToggleRow(
            label: "usesRangeBasedHighlighting",
            value: $configuration.current.performance.usesRangeBasedHighlighting
        )
        PickerRow(
            label: "renderingUpdateStrategy",
            value: $configuration.current.performance.renderingUpdateStrategy,
            cases: [.adaptive, .immediate, .batched]
        ) {
            String(describing: $0).capitalized
        }
    }

    @ViewBuilder
    private var debounceSection: some View {
        KnobSubsection(title: "Debounce")
        DurationRow(
            label: "highlightingDebounceInterval",
            value: $configuration.current.performance.highlightingDebounceInterval,
            rangeMS: 0...1_000
        )
        DurationRow(
            label: "textChangeDebounceInterval",
            value: $configuration.current.performance.textChangeDebounceInterval,
            rangeMS: 0...1_000
        )
    }

    @ViewBuilder
    private var iOSSection: some View {
        #if canImport(UIKit)
        KnobSubsection(title: "iOS Large Files")
        ToggleRow(
            label: "enableIOSOptimizations",
            value: $configuration.current.performance.enableIOSOptimizations
        )
        StepperRow(
            label: "iOSLargeFileThreshold",
            value: $configuration.current.performance.iOSLargeFileThreshold,
            range: 65_536...10_485_760,
            step: 65_536
        )
        StepperRow(
            label: "iOSMaxHighlightingChunk",
            value: $configuration.current.performance.iOSMaxHighlightingChunk,
            range: 4_096...1_048_576,
            step: 4_096
        )
        #else
        EmptyView()
        #endif
    }
}
