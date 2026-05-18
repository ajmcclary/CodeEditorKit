#if canImport(AppKit)
import AppKit
import CodeEditorSwiftUI
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform string pasteboard write. Used by the sample's
/// inspector Copy button. Sample-side helper — the framework does not
/// need a pasteboard surface today.
enum Pasteboard {
    @MainActor
    static func writeString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
