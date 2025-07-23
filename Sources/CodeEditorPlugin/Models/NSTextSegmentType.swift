import Foundation

/// Represents different types of text segments for rendering and layout
public enum NSTextSegmentType {
    /// Standard text segment with default appearance
    case standard
    /// Text segment that is part of a selection
    case selection
    /// Text segment that should be highlighted
    case highlight
}
