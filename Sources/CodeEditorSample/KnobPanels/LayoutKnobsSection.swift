import CodeEditorPlugin
import SwiftUI

struct LayoutKnobsSection: View {
    @Environment(\.codeEditorTheme) private var theme
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $expanded,
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    tabRows
                    KnobRowSeparator()
                    spacingRows
                    KnobRowSeparator()
                    widthAndBadgeRows
                    KnobRowSeparator()
                    minimapAndFoldingRows
                }
                .padding(.vertical, 4)
            },
            label: {
                Text("Layout")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
            }
        )
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var tabRows: some View {
        StepperRow(label: "tabWidth", value: $configuration.layout.tabWidth, range: 1...8)
        KnobRowSeparator()
        ToggleRow(label: "insertSpacesForTabs", value: $configuration.layout.insertSpacesForTabs)
        KnobRowSeparator()
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
        KnobRowSeparator()
        CGFloatSliderRow(
            label: "lineNumberPadding",
            value: $configuration.layout.lineNumberPadding,
            range: 0...40,
            step: 0.5
        )
        KnobRowSeparator()
        CGFloatSliderRow(
            label: "lineHeightMultiple",
            value: $configuration.layout.lineHeightMultiple,
            range: 0.0...2.0,
            step: 0.05
        )
        KnobRowSeparator()
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
        KnobRowSeparator()
        CGFloatSliderRow(
            label: "annotationBadgeSize",
            value: $configuration.layout.annotationBadgeSize,
            range: 6...32,
            step: 0.5
        )
        KnobRowSeparator()
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
        KnobRowSeparator()
        CGFloatSliderRow(
            label: "foldingControlSize",
            value: $configuration.layout.foldingControlSize,
            range: 6...24,
            step: 0.5
        )
        KnobRowSeparator()
        CGFloatSliderRow(
            label: "foldingControlPadding",
            value: $configuration.layout.foldingControlPadding,
            range: 0...12,
            step: 0.5
        )
    }
}
