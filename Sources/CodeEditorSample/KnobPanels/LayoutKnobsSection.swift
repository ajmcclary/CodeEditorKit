import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorPlugin
import SwiftUI

// `FrameworkEdgeInsets` is exported by `CodeEditorPlugin` to disambiguate
// from `SwiftUI.EdgeInsets`. Same value type as the framework's internal
// `EdgeInsets`, just under a non-conflicting name.

struct LayoutKnobsSection: View {
    @Bindable var configuration: ConfigurationModel
    @State private var expanded: Bool = false
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Layout",
            icon: "rectangle.split.3x1",
            accentIndex: 1,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                tabsSection
                spacingSection
                textContainerInsetSection
                widthAndBadgeSection
                minimapAndFoldingSection
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var textContainerInsetSection: some View {
        KnobSubsection(title: "Text Container Inset")
        CGFloatSliderRow(
            label: "top",
            value: insetBinding(\FrameworkEdgeInsets.top),
            range: 0...64,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "left",
            value: insetBinding(\FrameworkEdgeInsets.left),
            range: 0...64,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "bottom",
            value: insetBinding(\FrameworkEdgeInsets.bottom),
            range: 0...64,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "right",
            value: insetBinding(\FrameworkEdgeInsets.right),
            range: 0...64,
            step: 0.5
        )
    }

    private func insetBinding(
        _ keyPath: WritableKeyPath<FrameworkEdgeInsets, CGFloat>
    ) -> Binding<CGFloat> {
        Binding(
            get: { configuration.current.layout.textContainerInset[keyPath: keyPath] },
            set: { configuration.current.layout.textContainerInset[keyPath: keyPath] = $0 }
        )
    }

    @ViewBuilder
    private var tabsSection: some View {
        KnobSubsection(title: "Tabs")
        StepperRow(label: "tabWidth", value: $configuration.current.layout.tabWidth, range: 1...8)
        ToggleRow(label: "insertSpacesForTabs", value: $configuration.current.layout.insertSpacesForTabs)
        ToggleRow(label: "wrapLines", value: $configuration.current.layout.wrapLines)
    }

    @ViewBuilder
    private var spacingSection: some View {
        KnobSubsection(title: "Spacing")
        CGFloatSliderRow(
            label: "gutterWidth",
            value: $configuration.current.layout.gutterWidth,
            range: 0...80,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "lineNumberPadding",
            value: $configuration.current.layout.lineNumberPadding,
            range: 0...40,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "lineHeightMultiple",
            value: $configuration.current.layout.lineHeightMultiple,
            range: 0.0...2.0,
            step: 0.05
        )
        CGFloatSliderRow(
            label: "characterSpacing",
            value: $configuration.current.layout.characterSpacing,
            range: 0.0...4.0,
            step: 0.05
        )
    }

    @ViewBuilder
    private var widthAndBadgeSection: some View {
        KnobSubsection(title: "Width & Badges")
        CGFloatSliderRow(
            label: "textContainerWidthFraction",
            value: $configuration.current.layout.textContainerWidthFraction,
            range: 0.5...1.0,
            step: 0.05
        )
        CGFloatSliderRow(
            label: "annotationBadgeSize",
            value: $configuration.current.layout.annotationBadgeSize,
            range: 6...32,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "annotationBadgePadding",
            value: $configuration.current.layout.annotationBadgePadding,
            range: 0...16,
            step: 0.5
        )
    }

    @ViewBuilder
    private var minimapAndFoldingSection: some View {
        KnobSubsection(title: "Minimap & Folding")
        CGFloatSliderRow(
            label: "minimapWidth",
            value: $configuration.current.layout.minimapWidth,
            range: 40...240,
            step: 1
        )
        CGFloatSliderRow(
            label: "foldingControlSize",
            value: $configuration.current.layout.foldingControlSize,
            range: 6...24,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "foldingControlPadding",
            value: $configuration.current.layout.foldingControlPadding,
            range: 0...12,
            step: 0.5
        )
    }
}
