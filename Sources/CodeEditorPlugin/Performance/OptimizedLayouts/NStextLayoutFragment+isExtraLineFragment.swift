//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension NSTextLayoutFragment {
    package var isExtraLineFragment: Bool {
        textLineFragments.contains(where: \.isExtraLineFragment)
    }
}
