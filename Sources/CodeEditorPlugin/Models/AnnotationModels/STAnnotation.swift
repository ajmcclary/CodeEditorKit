//  Created by Claude Code
//  Annotation model

import Foundation

/// Represents an annotation in the text
public struct STAnnotation {
    public let id: String
    public let range: NSTextRange
    public let content: String
    
    public init(id: String = UUID().uuidString, range: NSTextRange, content: String) {
        self.id = id
        self.range = range
        self.content = content
    }
}