import CodeEditorPlugin
import SwiftUI

/// A single row inside the switcher card: leading SF Symbol, small-caps
/// label, current value, trailing chevron. Wraps a `Menu` so tapping
/// opens the option list.
struct SwitcherChip<Option: Hashable>: View {
    @Environment(\.codeEditorTheme) private var theme

    let icon: String
    let label: String
    let options: [Option]
    let optionLabel: (Option) -> String
    @Binding var selection: Option
    var disabled: Bool = false

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(optionLabel(option), systemImage: "checkmark")
                    } else {
                        Text(optionLabel(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.icon.muted))
                    .frame(width: 18, height: 18)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                    .frame(width: 64, alignment: .leading)
                Spacer(minLength: 4)
                Text(currentValueText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var currentValueText: String {
        guard !options.isEmpty else { return "—" }
        return optionLabel(selection)
    }
}
