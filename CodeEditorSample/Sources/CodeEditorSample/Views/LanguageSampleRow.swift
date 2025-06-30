import SwiftUI

/// A view that represents a language sample row using LanguageDetectionService
@available(macOS 13.0, iOS 16.0, *)
struct LanguageSampleRow: View {
    let languageInfo: LanguageDetectionService.LanguageInfo
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: languageInfo.icon ?? "doc.text")
                .foregroundColor(languageInfo.iconColor ?? .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading) {
                Text(languageInfo.displayName)
                    .font(.body)
                if let firstExtension = languageInfo.fileExtensions.first {
                    Text(".\(firstExtension)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
