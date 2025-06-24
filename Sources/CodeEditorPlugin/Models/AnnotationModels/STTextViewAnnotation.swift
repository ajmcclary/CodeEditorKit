//  Created by Claude Code
//  Text view annotation model

import Foundation

/// Represents an annotation with location in text view
public struct STTextViewAnnotation {
    public var id: String
    public var location: NSTextLocation
    public var content: String
    
    public init(id: String = UUID().uuidString, location: NSTextLocation, content: String) {
        self.id = id
        self.location = location
        self.content = content
    }
}