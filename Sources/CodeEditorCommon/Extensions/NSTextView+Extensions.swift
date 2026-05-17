#if canImport(AppKit)
import AppKit

typealias TextView = NSTextView
#elseif canImport(UIKit)
import UIKit

typealias TextView = UITextView
#endif

// Note: The actual text view extensions have been moved to TextView+UnifiedExtensions.swift
// This file is kept for backward compatibility with the TextView type alias
