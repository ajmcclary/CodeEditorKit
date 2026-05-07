import CodeEditorPlugin
import SwiftUI

struct BehaviorKnobsSection: View {
    @Environment(\.codeEditorTheme) private var theme
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $expanded,
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    editingRows
                    KnobRowSeparator()
                    automaticRows
                    KnobRowSeparator()
                    spellingRows
                    KnobRowSeparator()
                    completionRows
                }
                .padding(.vertical, 4)
            },
            label: {
                Text("Behavior")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
            }
        )
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var editingRows: some View {
        ToggleRow(label: "isEditable", value: $configuration.behavior.isEditable)
        KnobRowSeparator()
        ToggleRow(label: "isSelectable", value: $configuration.behavior.isSelectable)
        KnobRowSeparator()
        ToggleRow(label: "isAutoIndentEnabled", value: $configuration.behavior.isAutoIndentEnabled)
        KnobRowSeparator()
        ToggleRow(label: "autoScrollToCursor", value: $configuration.behavior.autoScrollToCursor)
    }

    @ViewBuilder
    private var automaticRows: some View {
        ToggleRow(
            label: "isAutomaticLinkDetectionEnabled",
            value: $configuration.behavior.isAutomaticLinkDetectionEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "isAutomaticQuoteSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticQuoteSubstitutionEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "isAutomaticDashSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticDashSubstitutionEnabled
        )
        KnobRowSeparator()
        ToggleRow(label: "autoCloseBrackets", value: $configuration.behavior.autoCloseBrackets)
        KnobRowSeparator()
        ToggleRow(label: "autoCloseQuotes", value: $configuration.behavior.autoCloseQuotes)
    }

    @ViewBuilder
    private var spellingRows: some View {
        ToggleRow(
            label: "isContinuousSpellCheckingEnabled",
            value: $configuration.behavior.isContinuousSpellCheckingEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "isGrammarCheckingEnabled",
            value: $configuration.behavior.isGrammarCheckingEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "isAutomaticTextReplacementEnabled",
            value: $configuration.behavior.isAutomaticTextReplacementEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "isAutomaticSpellingCorrectionEnabled",
            value: $configuration.behavior.isAutomaticSpellingCorrectionEnabled
        )
    }

    @ViewBuilder
    private var completionRows: some View {
        ToggleRow(label: "isCodeCompletionEnabled", value: $configuration.behavior.isCodeCompletionEnabled)
        KnobRowSeparator()
        ToggleRow(
            label: "isAutomaticTextCompletionEnabled",
            value: $configuration.behavior.isAutomaticTextCompletionEnabled
        )
        KnobRowSeparator()
        ToggleRow(
            label: "showInlineCompletionSuggestions",
            value: $configuration.behavior.showInlineCompletionSuggestions
        )
        KnobRowSeparator()
        CharSetRow(
            label: "completionTriggerCharacters",
            value: $configuration.behavior.completionTriggerCharacters
        )
    }
}
