#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
@MainActor
class TextLocation: UITextPosition {
    package let location: NSTextLocation

    override var debugDescription: String {
        "TextLocation"
    }

    init(location: NSTextLocation) {
        self.location = location
        super.init()
    }

    deinit {
        // Cleanup if needed
    }
}
#else
/// macOS equivalent - UITextPosition doesn't exist on macOS
class TextLocation {
    package let location: NSTextLocation

    package var debugDescription: String {
        location.description
    }

    init(location: NSTextLocation) {
        self.location = location
    }

    deinit {
        // Cleanup if needed
    }
}
#endif

extension NSTextLocation {
    @MainActor
    var uiTextPosition: TextLocation {
        TextLocation(location: self)
    }
}
