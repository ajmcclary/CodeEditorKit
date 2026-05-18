#if canImport(AppKit)
import CodeEditorCommon
import CodeEditorPlugin
import CodeEditorSwiftUI
import Foundation

/// Maintains a one-to-one mapping between in-memory tabs and on-disk shadow
/// files so sourcekit-lsp has a real URI per document. Writes are debounced
/// to coalesce rapid keystroke updates before they leave the editor.
@MainActor
final class DocumentMirror {
    private let shadowDirectory: URL
    private let debounceInterval: TimeInterval
    private var shadowURLs: [UUID: URL] = [:]
    private var pendingWork: [UUID: DispatchWorkItem] = [:]

    init(rootDirectory: URL, debounceInterval: TimeInterval = 0.15) {
        self.shadowDirectory = rootDirectory.appendingPathComponent(".codeeditor-sample")
        self.debounceInterval = debounceInterval
        try? FileManager.default.createDirectory(
            at: shadowDirectory, withIntermediateDirectories: true
        )
    }

    /// Writes `text` to a new shadow file under the mirror's directory and
    /// returns the URL.
    @discardableResult
    func openTab(id: UUID, text: String, fileExtension: String) throws -> URL {
        let url = shadowDirectory.appendingPathComponent("\(id.uuidString).\(fileExtension)")
        let data = text.data(using: .utf8) ?? Data()
        try data.write(to: url, options: .atomic)
        shadowURLs[id] = url
        return url
    }

    /// Schedule a debounced write. After `debounceInterval` of quiet time,
    /// the latest `newText` lands on disk.
    func handleTextChange(id: UUID, newText: String) {
        guard let url = shadowURLs[id] else { return }
        pendingWork[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let data = newText.data(using: .utf8) ?? Data()
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                CrossPlatformLogger.logger().error("DocumentMirror write failed: \(error)")
            }
            self.pendingWork[id] = nil
        }
        pendingWork[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Send any pending write immediately, delete the shadow file, and
    /// forget the tab.
    func closeTab(id: UUID) {
        pendingWork[id]?.cancel()
        pendingWork[id] = nil
        if let url = shadowURLs.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Look up the shadow URL for an open tab. Returns nil for unknown ids.
    func url(for id: UUID) -> URL? {
        shadowURLs[id]
    }

    /// Remove any files in the shadow directory that aren't tracked by an
    /// open tab. Safe to call on `start()` to evict leftovers from a prior
    /// run.
    func cleanupStaleShadows() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: shadowDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        let known = Set(shadowURLs.values.map(\.standardizedFileURL))
        for item in contents where !known.contains(item.standardizedFileURL) {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
#endif
