//  Created by Claude Code
//  Missing protocol for consolidated package

import Foundation

/// Protocol for text system interface
public protocol TextSystemInterface {
    associatedtype Content: VersionedContent
    
    var textContentManager: NSTextContentManager { get }
    var content: Content { get }
}