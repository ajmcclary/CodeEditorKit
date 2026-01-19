import Foundation

// MARK: - File System Actor

/// Actor responsible for file system operations
@available(macOS 13.0, iOS 16.0, *)
public actor FileSystemActor {
    private let fileManager = FileManager.default
    private var fileHandles: [URL: FileHandle] = [:]
    private var watchers: [URL: FileWatcher] = [:]

    private struct FileWatcher {
        let url: URL
        let handler: @Sendable (FileChangeNotification) async -> Void
        let source: DispatchSourceFileSystemObject?
    }

    /// Read file contents
    public func readFile(at url: URL) async throws -> String {
        if let handle = fileHandles[url] {
            try handle.seek(toOffset: 0)
            let data = handle.readDataToEndOfFile()
            guard let content = String(data: data, encoding: .utf8) else {
                throw CodeEditorError.encodingFailed(.utf8)
            }
            return content
        }

        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }
        return content
    }

    /// Write file contents
    public func writeFile(_ content: String, to url: URL) async throws {
        guard let data = content.data(using: .utf8) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }

        if fileHandles[url] != nil {
            closeFile(at: url)
        }

        try data.write(to: url)
    }

    /// Open file handle for repeated access
    public func openFile(at url: URL) throws {
        guard fileHandles[url] == nil else { return }

        let handle = try FileHandle(forReadingFrom: url)
        fileHandles[url] = handle
    }

    /// Close file handle
    public func closeFile(at url: URL) {
        if let handle = fileHandles[url] {
            try? handle.close()
            fileHandles.removeValue(forKey: url)
        }
    }

    /// Watch file for changes
    public func watchFile(
        at url: URL,
        handler: @escaping @Sendable (FileChangeNotification) async -> Void
    ) throws {
        guard watchers[url] == nil else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard self != nil else { return }

            let notification: FileChangeNotification
            if source.data.contains(.delete) {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .deleted
                )
            } else if source.data.contains(.rename) {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .renamed(from: url.path, to: url.path)
                )
            } else {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .modified
                )
            }

            Task {
                await handler(notification)
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()

        watchers[url] = FileWatcher(
            url: url,
            handler: handler,
            source: source
        )
    }

    /// Stop watching file
    public func unwatchFile(at url: URL) {
        if let watcher = watchers[url] {
            watcher.source?.cancel()
            watchers.removeValue(forKey: url)
        }
    }

    deinit {
        // Clean up file handles and watchers synchronously
        for (_, handle) in fileHandles {
            try? handle.close()
        }

        for (_, watcher) in watchers {
            watcher.source?.cancel()
        }
    }
}
