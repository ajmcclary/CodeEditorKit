//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
internal class STTextLocation: UITextPosition {
    let location: NSTextLocation

    override var debugDescription: String {
        location.description
    }

    init(location: NSTextLocation) {
        self.location = location
        super.init()
    }
}
#else
// macOS equivalent - UITextPosition doesn't exist on macOS
internal class STTextLocation {
    let location: NSTextLocation

    var debugDescription: String {
        location.description
    }

    init(location: NSTextLocation) {
        self.location = location
    }
}
#endif

internal extension NSTextLocation {
    var uiTextPosition: STTextLocation {
        STTextLocation(location: self)
    }
}