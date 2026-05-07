import CodeEditorPlugin
import SwiftUI

/// Small-caps group label rendered between knob rows. Acts as the title
/// for an inline subsection — paired hairlines flank the text so it reads
/// as a divider rather than a heading.
struct KnobSubsection: View {
    @Environment(\.codeEditorTheme) private var theme

    let title: String

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .fixedSize()
            line
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var line: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.variant))
            .frame(height: 0.5)
    }
}
