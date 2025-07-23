import Foundation
import SwiftUI

// MARK: - Completion Popup State

/// State management for the completion popup UI
public struct CompletionPopupState {
    public var isVisible: Bool
    public var position: CGPoint
    public var size: CGSize
    public var selectedIndex: Int
    public var isLoading: Bool
    public var animationDuration: TimeInterval

    public init(
        isVisible: Bool = false,
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 300, height: 200),
        selectedIndex: Int = 0,
        isLoading: Bool = false,
        animationDuration: TimeInterval = 0.2
    ) {
        self.isVisible = isVisible
        self.position = position
        self.size = size
        self.selectedIndex = selectedIndex
        self.isLoading = isLoading
        self.animationDuration = animationDuration
    }
}

// MARK: - Completion Context

/// Context information for completion generation
public struct CompletionContext: Sendable {
    public let triggerLocation: Int
    public let triggerCharacter: String?
    public let prefix: String
    public let currentLine: String
    public let language: Language
    public let contextRange: NSRange

    public init(
        triggerLocation: Int,
        triggerCharacter: String?,
        prefix: String,
        currentLine: String,
        language: Language,
        contextRange: NSRange
    ) {
        self.triggerLocation = triggerLocation
        self.triggerCharacter = triggerCharacter
        self.prefix = prefix
        self.currentLine = currentLine
        self.language = language
        self.contextRange = contextRange
    }
}

// MARK: - Completion Item

/// Simplified completion item for UI presentation
public struct CompletionItem: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let kind: CompletionItemKind
    public let detail: String?
    public let documentation: String?
    public let insertText: String?
    public let priority: Int
    public let matchScore: Double

    public init(
        text: String,
        kind: CompletionItemKind,
        detail: String? = nil,
        documentation: String? = nil,
        insertText: String? = nil,
        priority: Int = 0,
        matchScore: Double = 1.0
    ) {
        self.text = text
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.insertText = insertText
        self.priority = priority
        self.matchScore = matchScore
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Completion Item Kind Extension

// Note: The icon and priority properties are already defined in CompletionModels.swift
// No need to duplicate them here

// MARK: - Selection Direction

/// Direction for moving selection in completion popup
public enum SelectionDirection {
    case up
    case down
    case pageUp
    case pageDown
    case first
    case last
}
