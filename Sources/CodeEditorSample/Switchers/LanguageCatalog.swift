import CodeEditorPlugin
import Foundation

/// Display-name-sorted list of `Language` cases for the language picker.
enum LanguageCatalog {
    static let all: [Language] = Language.allCases.sorted { $0.name < $1.name }

    /// Default for new tabs.
    static let `default`: Language = .swift
}
