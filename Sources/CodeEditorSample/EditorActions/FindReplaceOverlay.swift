import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorSwiftUI
import SwiftUI

/// Xcode-style overlay banner pinned to the top of the editor pane.
/// View-only: reads / writes `FindReplaceModel`, calls the model's
/// helpers which dispatch into the framework via `EditorController`.
struct FindReplaceOverlay: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: FindReplaceModel
    let controller: EditorController
    let isReadOnly: Bool

    @FocusState private var focusedField: Field?

    private enum Field { case find, replace }

    var body: some View {
        VStack(spacing: 0) {
            findRow
            Divider().background(Color(tokens: theme.style.borders.variant))
            replaceRow
            if model.isOptionsExpanded {
                Divider().background(Color(tokens: theme.style.borders.variant))
                optionsRow
            }
        }
        .padding(8)
        .background(panelBackground)
        .padding(10)
        .onAppear { focusedField = .find }
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Find", text: $model.findText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .find)
            badge
            Button {
                Task { await model.runSearch(controller: controller) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-run search")
            Button { model.findPrevious(controller: controller) } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")
            Button { model.findNext(controller: controller) } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    model.isOptionsExpanded.toggle()
                }
            } label: {
                Image(systemName: model.isOptionsExpanded
                    ? "chevron.up.square"
                    : "chevron.down.square")
            }
            .help("Options")
            Button { model.close(controller: controller) } label: {
                Image(systemName: "xmark")
            }
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close")
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }

    @ViewBuilder
    private var badge: some View {
        if model.lastError == .invalidRegex {
            Text("Invalid regex")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        } else if model.matchCount > 0 {
            Text("\(model.currentMatchPosition) / \(model.matchCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens: theme.style.elements.element.background))
                )
        } else if !model.findText.isEmpty {
            Text("0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Replace", text: $model.replaceText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .replace)
            Spacer()
            Button("Replace") {
                model.replaceCurrent(controller: controller)
            }
            .disabled(!model.canReplace(matchCount: model.matchCount, isReadOnly: isReadOnly))
            Button("All") {
                Task { await model.replaceAll(controller: controller) }
            }
            .disabled(!model.canReplace(matchCount: model.matchCount, isReadOnly: isReadOnly))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Options row

    private var optionsRow: some View {
        HStack(spacing: 14) {
            optionToggle(label: "Aa", help: "Match case", isOn: $model.options.caseSensitive)
            optionToggle(label: "|W|", help: "Whole word", isOn: $model.options.wholeWord)
            optionToggle(label: ".*", help: "Regular expression", isOn: $model.options.useRegularExpression)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func optionToggle(label: String, help: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn.wrappedValue
                            ? Color.accentColor.opacity(0.3)
                            : Color(tokens: theme.style.elements.element.background))
                )
                .foregroundStyle(isOn.wrappedValue
                    ? Color.accentColor
                    : Color(tokens: theme.style.text.muted))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(tokens: theme.style.borders.base), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}
