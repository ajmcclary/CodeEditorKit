import CodeEditorDesignTokens
import CodeEditorLanguages
import CodeEditorPlugin
import SwiftUI

/// Filterable list of `EditorController.symbols`. Picking a row calls
/// `controller.gotoSymbol(_:)` and dismisses.
struct GotoSymbolSheet: View {
    @Environment(\.codeEditorTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let controller: EditorController
    @State private var filter: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Go to Symbol")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(tokens: theme.style.text.base))
            TextField("Filter", text: $filter)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if visibleSymbols.isEmpty {
                        emptyState
                    }
                    ForEach(visibleSymbols, id: \.id) { symbol in
                        Button {
                            controller.gotoSymbol(symbol)
                            dismiss()
                        } label: {
                            row(for: symbol)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 220, maxHeight: 320)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(tokens: theme.style.elements.element.background))
            )
            HStack {
                Spacer()
                Button("Close", role: .cancel) { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { controller.refreshSymbols() }
    }

    private var visibleSymbols: [DocumentSymbol] {
        let all = flatten(controller.symbols)
        guard !filter.isEmpty else { return all }
        let needle = filter.lowercased()
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    private func flatten(_ symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        var out: [DocumentSymbol] = []
        for symbol in symbols {
            out.append(symbol)
            out.append(contentsOf: flatten(symbol.children))
        }
        return out
    }

    private func row(for symbol: DocumentSymbol) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(for: symbol.kind))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.accent))
                .frame(width: 14)
            Text(symbol.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
            Spacer()
            Text(symbol.kind.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        Text(controller.symbols.isEmpty ? "No symbols detected." : "No matches.")
            .font(.system(size: 11))
            .foregroundStyle(Color(tokens: theme.style.text.muted))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private func icon(for kind: DocumentSymbolKind) -> String {
        switch kind {
        case .function, .method: return "function"
        case .class: return "cube"
        case .struct: return "square.3.layers.3d"
        case .enum, .enumMember: return "list.bullet"
        case .interface: return "rectangle.stack"
        case .variable, .property, .field: return "circle.fill"
        case .constant: return "circle.dashed"
        case .constructor: return "plus.circle"
        case .namespace, .module, .package: return "shippingbox"
        case .file: return "doc"
        default: return "circle"
        }
    }
}
