import CodeEditorPlugin
import SwiftUI

struct LayoutKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Layout", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                tabRows
                spacingRows
                widthAndBadgeRows
                minimapAndFoldingRows
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var tabRows: some View {
        StepperRow(label: "tabWidth", value: $configuration.layout.tabWidth, range: 1...8)
        ToggleRow(label: "insertSpacesForTabs", value: $configuration.layout.insertSpacesForTabs)
        ToggleRow(label: "wrapLines", value: $configuration.layout.wrapLines)
    }

    @ViewBuilder
    private var spacingRows: some View {
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
    private var widthAndBadgeRows: some View {
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
    private var minimapAndFoldingRows: some View {
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
