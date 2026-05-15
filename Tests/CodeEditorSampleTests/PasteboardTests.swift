@testable import CodeEditorSample
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("Pasteboard helper")
struct PasteboardTests {
    @Test("writeString round-trips through the platform pasteboard")
    func writeRoundTrips() {
        let sentinel = "round-trip-\(UUID().uuidString)"
        Pasteboard.writeString(sentinel)

        #if canImport(AppKit)
        let read = NSPasteboard.general.string(forType: .string)
        #elseif canImport(UIKit)
        let read = UIPasteboard.general.string
        #else
        let read: String? = nil
        #endif

        #expect(read == sentinel)
    }
}
