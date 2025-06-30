import CodeEditorPlugin
import Foundation
import SwiftUI

/// A reusable service for language detection and information
public struct LanguageDetectionService {
    
    // MARK: - Types
    
    /// Information about a programming language
    public struct LanguageInfo: Sendable {
        public let id: String
        public let displayName: String
        public let fileExtensions: [String]
        public let icon: String?
        public let iconColor: Color?
        public let sampleCode: String?
        
        public init(
            id: String,
            displayName: String,
            fileExtensions: [String],
            icon: String? = nil,
            iconColor: Color? = nil,
            sampleCode: String? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.fileExtensions = fileExtensions
            self.icon = icon
            self.iconColor = iconColor
            self.sampleCode = sampleCode
        }
    }
    
    // MARK: - Language Registry
    
    private static let languages: [LanguageInfo] = [
        LanguageInfo(
            id: "swift",
            displayName: "Swift",
            fileExtensions: ["swift"],
            icon: "swift",
            iconColor: .orange
        ),
        LanguageInfo(
            id: "javascript",
            displayName: "JavaScript",
            fileExtensions: ["js", "jsx", "mjs"],
            icon: "curlybraces",
            iconColor: .yellow
        ),
        LanguageInfo(
            id: "typescript",
            displayName: "TypeScript",
            fileExtensions: ["ts", "tsx"],
            icon: "curlybraces",
            iconColor: .blue
        ),
        LanguageInfo(
            id: "python",
            displayName: "Python",
            fileExtensions: ["py", "pyw"],
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: .cyan
        ),
        LanguageInfo(
            id: "go",
            displayName: "Go",
            fileExtensions: ["go"],
            icon: "g.square",
            iconColor: .teal
        ),
        LanguageInfo(
            id: "rust",
            displayName: "Rust",
            fileExtensions: ["rs"],
            icon: "r.square",
            iconColor: .brown
        ),
        LanguageInfo(
            id: "cpp",
            displayName: "C++",
            fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx", "c++"],
            icon: "c.square",
            iconColor: .indigo
        ),
        LanguageInfo(
            id: "c",
            displayName: "C",
            fileExtensions: ["c", "h"],
            icon: "c.square",
            iconColor: .blue
        ),
        LanguageInfo(
            id: "java",
            displayName: "Java",
            fileExtensions: ["java"],
            icon: "cup.and.saucer",
            iconColor: .red
        ),
        LanguageInfo(
            id: "html",
            displayName: "HTML",
            fileExtensions: ["html", "htm", "xhtml"],
            icon: "safari",
            iconColor: .orange
        ),
        LanguageInfo(
            id: "css",
            displayName: "CSS",
            fileExtensions: ["css", "scss", "sass", "less"],
            icon: "paintbrush",
            iconColor: .blue
        ),
        LanguageInfo(
            id: "json",
            displayName: "JSON",
            fileExtensions: ["json", "jsonc"],
            icon: "doc.text",
            iconColor: .gray
        ),
        LanguageInfo(
            id: "markdown",
            displayName: "Markdown",
            fileExtensions: ["md", "markdown", "mdown", "mkd"],
            icon: "text.alignleft",
            iconColor: .purple
        ),
        LanguageInfo(
            id: "yaml",
            displayName: "YAML",
            fileExtensions: ["yaml", "yml"],
            icon: "list.bullet",
            iconColor: .green
        ),
        LanguageInfo(
            id: "xml",
            displayName: "XML",
            fileExtensions: ["xml", "xsl", "xslt"],
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: .orange
        ),
        LanguageInfo(
            id: "sql",
            displayName: "SQL",
            fileExtensions: ["sql"],
            icon: "server.rack",
            iconColor: .mint
        ),
        LanguageInfo(
            id: "ruby",
            displayName: "Ruby",
            fileExtensions: ["rb", "rbw"],
            icon: "r.square",
            iconColor: .red
        ),
        LanguageInfo(
            id: "php",
            displayName: "PHP",
            fileExtensions: ["php", "phtml", "php3", "php4", "php5"],
            icon: "p.square",
            iconColor: .purple
        )
    ]
    
    // MARK: - Public Methods
    
    /// Detect language from file extension
    public static func detectLanguage(from fileExtension: String) -> LanguageInfo? {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return languages.first { $0.fileExtensions.contains(ext) }
    }
    
    /// Get language by identifier
    public static func language(for identifier: String) -> LanguageInfo? {
        return languages.first { $0.id == identifier.lowercased() }
    }
    
    /// Get all supported languages
    public static var allLanguages: [LanguageInfo] {
        return languages.sorted { $0.displayName < $1.displayName }
    }
    
    /// Get all supported file extensions
    public static var allFileExtensions: Set<String> {
        return Set(languages.flatMap { $0.fileExtensions })
    }
    
    /// Convert to CodeEditorPlugin Language enum
    /// Note: This returns .plainText for all languages except Swift because
    /// the actual language detection happens when setting a file extension
    /// on the CodeEditorView instance.
    public static func editorLanguage(for languageInfo: LanguageInfo?) -> Language {
        guard let info = languageInfo else { return .plainText }
        
        // Only Swift has a dedicated enum case
        if info.id == "swift" {
            return .swift
        }
        
        // All other languages use the regex-based highlighter
        // which is set via setLanguage(fileExtension:) on the view
        return .plainText
    }
    
    /// Check if a file type is supported
    public static func isSupported(fileExtension: String) -> Bool {
        return detectLanguage(from: fileExtension) != nil
    }
    
    /// Get a suggested file name for a language
    public static func suggestedFileName(for languageInfo: LanguageInfo) -> String {
        let baseName = "untitled"
        guard let ext = languageInfo.fileExtensions.first else {
            return baseName
        }
        return "\(baseName).\(ext)"
    }
}

// MARK: - Extensions

extension LanguageDetectionService.LanguageInfo: Identifiable {
    // id property already exists in the struct
}

extension LanguageDetectionService.LanguageInfo: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension LanguageDetectionService.LanguageInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
