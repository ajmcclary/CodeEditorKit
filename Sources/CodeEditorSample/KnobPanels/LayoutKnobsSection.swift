import CodeEditorPlugin
import SwiftUI

struct LayoutKnobsSection: View {
    @Binding var configuration: EditorConfiguration
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
                widthAndBadgeSection
                minimapAndFoldingSection
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var tabsSection: some View {
        KnobSubsection(title: "Tabs")
        StepperRow(label: "tabWidth", value: $configuration.layout.tabWidth, range: 1...8)
        ToggleRow(label: "insertSpacesForTabs", value: $configuration.layout.insertSpacesForTabs)
        ToggleRow(label: "wrapLines", value: $configuration.layout.wrapLines)
    }

    @ViewBuilder
    private var spacingSection: some View {
        KnobSubsection(title: "Spacing")
        CGFloatSliderRow(
            label: "gutterWidth",
            value: $configuration.layout.gutterWidth,
            range: 0...80,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "lineNumberPadding",
            value: $configuration.layout.lineNumberPadding,
            range: 0...40,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "lineHeightMultiple",
            value: $configuration.layout.lineHeightMultiple,
            range: 0.0...2.0,
            step: 0.05
        )
        CGFloatSliderRow(
            label: "characterSpacing",
            value: $configuration.layout.characterSpacing,
            range: 0.0...4.0,
            step: 0.05
        )
    }

    @ViewBuilder
    private var widthAndBadgeSection: some View {
        KnobSubsection(title: "Width & Badges")
        CGFloatSliderRow(
            label: "textContainerWidthFraction",
            value: $configuration.layout.textContainerWidthFraction,
            range: 0.5...1.0,
            step: 0.05
        )
        CGFloatSliderRow(
            label: "annotationBadgeSize",
            value: $configuration.layout.annotationBadgeSize,
            range: 6...32,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "annotationBadgePadding",
            value: $configuration.layout.annotationBadgePadding,
            range: 0...16,
            step: 0.5
        )
    }

    @ViewBuilder
    private var minimapAndFoldingSection: some View {
        KnobSubsection(title: "Minimap & Folding")
        CGFloatSliderRow(
            label: "minimapWidth",
            value: $configuration.layout.minimapWidth,
            range: 40...240,
            step: 1
        )
        CGFloatSliderRow(
            label: "foldingControlSize",
            value: $configuration.layout.foldingControlSize,
            range: 6...24,
            step: 0.5
        )
        CGFloatSliderRow(
            label: "foldingControlPadding",
            value: $configuration.layout.foldingControlPadding,
            range: 0...12,
            step: 0.5
        )
    }
}
