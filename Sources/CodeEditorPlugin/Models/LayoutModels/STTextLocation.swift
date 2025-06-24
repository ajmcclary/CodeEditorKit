#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
class STTextLocation: UITextPosition {
    let location: NSTextLocation

    override var debugDescription: String {
        location.description
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
class STTextLocation {
    let location: NSTextLocation

    var debugDescription: String {
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
    var uiTextPosition: STTextLocation {
        STTextLocation(location: self)
    }
}
