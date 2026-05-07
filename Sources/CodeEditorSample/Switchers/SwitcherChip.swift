import CodeEditorPlugin
import SwiftUI

/// A single row inside the switcher card. Two-line layout: small-caps
/// category label on top, current value as the dominant text below,
/// trailing chevron on the right edge. Tapping opens a `Menu` of options.
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
            chipBody
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var chipBody: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                Text(currentValueText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var currentValueText: String {
        guard !options.isEmpty else { return "—" }
        return optionLabel(selection)
    }
}
