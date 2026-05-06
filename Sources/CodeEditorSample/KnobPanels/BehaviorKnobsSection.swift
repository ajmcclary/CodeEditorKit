import CodeEditorPlugin
import SwiftUI

struct BehaviorKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Behavior", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                editingRows
                automaticRows
                spellingRows
                completionRows
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var editingRows: some View {
        ToggleRow(label: "isEditable", value: $configuration.behavior.isEditable)
        ToggleRow(label: "isSelectable", value: $configuration.behavior.isSelectable)
        ToggleRow(label: "isAutoIndentEnabled", value: $configuration.behavior.isAutoIndentEnabled)
        ToggleRow(label: "autoScrollToCursor", value: $configuration.behavior.autoScrollToCursor)
    }

    @ViewBuilder
    private var automaticRows: some View {
        ToggleRow(
            label: "isAutomaticLinkDetectionEnabled",
            value: $configuration.behavior.isAutomaticLinkDetectionEnabled
        )
        ToggleRow(
            label: "isAutomaticQuoteSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticQuoteSubstitutionEnabled
        )
        ToggleRow(
            label: "isAutomaticDashSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticDashSubstitutionEnabled
        )
        ToggleRow(label: "autoCloseBrackets", value: $configuration.behavior.autoCloseBrackets)
        ToggleRow(label: "autoCloseQuotes", value: $configuration.behavior.autoCloseQuotes)
    }

    @ViewBuilder
    private var spellingRows: some View {
        ToggleRow(
            label: "isContinuousSpellCheckingEnabled",
            value: $configuration.behavior.isContinuousSpellCheckingEnabled
        )
        ToggleRow(
            label: "isGrammarCheckingEnabled",
            value: $configuration.behavior.isGrammarCheckingEnabled
        )
        ToggleRow(
            label: "isAutomaticTextReplacementEnabled",
            value: $configuration.behavior.isAutomaticTextReplacementEnabled
        )
        ToggleRow(
            label: "isAutomaticSpellingCorrectionEnabled",
            value: $configuration.behavior.isAutomaticSpellingCorrectionEnabled
        )
    }

    @ViewBuilder
    private var completionRows: some View {
        ToggleRow(label: "isCodeCompletionEnabled", value: $configuration.behavior.isCodeCompletionEnabled)
        ToggleRow(
            label: "isAutomaticTextCompletionEnabled",
            value: $configuration.behavior.isAutomaticTextCompletionEnabled
        )
        ToggleRow(
            label: "showInlineCompletionSuggestions",
            value: $configuration.behavior.showInlineCompletionSuggestions
        )
        CharSetRow(
            label: "completionTriggerCharacters",
            value: $configuration.behavior.completionTriggerCharacters
        )
    }
}
