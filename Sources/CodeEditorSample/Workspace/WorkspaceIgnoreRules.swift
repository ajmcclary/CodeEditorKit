import CodeEditorSwiftUI
import Foundation

/// Centralized name-based filters for the workspace surface. Used by
/// `WorkspaceModel` (file tree) and `ProjectSearchModel` (indexing).
///
/// These rules are intentionally static. The sample doesn't parse
/// `.gitignore` or expose user configuration; if you need that, fork.
enum WorkspaceIgnoreRules {
    /// Names hidden from the file tree and excluded from search indexing.
    /// Covers dotfiles plus a small set of well-known build / vendor dirs.
    static let hiddenNames: Set<String> = [
        ".build",
        ".swiftpm",
        "node_modules",
        "DerivedData",
        "__Snapshots__"
    ]

    /// File extensions excluded from project-search indexing because the
    /// portable adapter can't usefully match against their bytes.
    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif",
        "pdf", "zip", "tar", "gz", "bz2", "xz", "7z",
        "mov", "mp4", "m4v", "mp3", "wav", "aiff",
        "ttf", "otf", "woff", "woff2",
        "dylib", "a", "so", "framework", "bundle"
    ]

    /// `true` when this file or directory name should be hidden from
    /// the workspace surface.
    static func shouldHide(name: String) -> Bool {
        if name.hasPrefix(".") { return true }
        return hiddenNames.contains(name)
    }

    /// `true` when this extension is in the binary deny-list. Case-insensitive.
    static func isBinaryExtension(_ ext: String) -> Bool {
        binaryExtensions.contains(ext.lowercased())
    }
}
