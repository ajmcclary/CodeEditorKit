import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ViewReuseQueue

/// A generic view reuse pool keyed by a `Hashable` identifier.
///
/// Reduces allocation pressure during scrolling by recycling off-screen
/// views instead of creating new ones. Pattern modeled after
/// `UITableView`/`UICollectionView` cell reuse.
///
/// ## Usage
///
/// ```swift
/// let queue = ViewReuseQueue<LineNumberView, Int>()
///
/// // During layout: get or create views for visible keys
/// for lineIndex in visibleLineRange {
///     let view = queue.getOrCreateView(forKey: lineIndex) {
///         LineNumberView(frame: .zero)
///     }
///     view.configure(lineNumber: lineIndex + 1)
///     addSubview(view)
/// }
///
/// // After layout: return non-visible views to the pool
/// queue.enqueueViews(notInSet: Set(visibleLineRange))
/// ```
///
/// - Note: This is a `@MainActor` class. All view mutations must occur
///   on the main thread.
@MainActor
public final class ViewReuseQueue<View: PlatformView, Key: Hashable> {
    /// Views available for reuse, grouped by key.
    private var available: [Key: [View]] = [:]

    /// All views currently checked out (not in the pool).
    private var checkedOut: Set<ObjectIdentifier> = []

    /// Reverse mapping from view identity to key for `enqueueViews(notInSet:)`.
    private var viewToKey: [ObjectIdentifier: Key] = [:]

    /// Active key-to-view mapping maintained externally by callers.
    /// Populated via `getOrCreateView(forKey:factory:)` and cleared
    /// by `enqueueViews(notInSet:)`.
    private var activeViews: [Key: View] = [:]

    /// Total number of views ever created.
    public private(set) var totalCreated: Int = 0

    /// Number of views currently in the reuse pool.
    public var pooledCount: Int {
        available.values.reduce(0) { $0 + $1.count }
    }

    /// Number of views currently checked out.
    public var activeCount: Int { checkedOut.count }

    // MARK: - Initialization

    /// Creates an empty reuse queue.
    public init() {}

    // MARK: - Public API

    /// Returns a view for the given key, either from the reuse pool or
    /// by calling `factory` to create a new one.
    ///
    /// The returned view is removed from the pool and considered "checked
    /// out" until returned via `enqueueViews(notInSet:)`.
    ///
    /// - Parameters:
    ///   - key: The key identifying the view's intended use (e.g., line index).
    ///   - factory: Closure that creates a new view when the pool is empty.
    /// - Returns: A view ready for configuration and display.
    public func getOrCreateView(forKey key: Key, factory: () -> View) -> View {
        if let view = dequeueAvailableView(preferredKey: key) {
            let id = ObjectIdentifier(view)
            checkedOut.insert(id)
            viewToKey[id] = key
            activeViews[key] = view
            return view
        }

        let view = factory()
        totalCreated += 1
        let id = ObjectIdentifier(view)
        checkedOut.insert(id)
        viewToKey[id] = key
        activeViews[key] = view
        return view
    }

    /// Returns all checked-out views whose keys are **not** in `activeKeys`
    /// to the reuse pool. Views with keys in `activeKeys` remain checked out.
    ///
    /// Call this after each layout pass to recycle off-screen views.
    ///
    /// - Parameter activeKeys: The set of keys that should remain active
    ///   (typically the currently visible line indices).
    public func enqueueViews(notInSet activeKeys: Set<Key>) {
        let keysToEnqueue = activeViews.keys.filter { !activeKeys.contains($0) }
        for key in keysToEnqueue {
            if let view = activeViews[key] {
                enqueueView(view, forKey: key)
            }
        }
    }

    /// Returns a specific view to the reuse pool under the given key.
    ///
    /// - Parameters:
    ///   - view: The view to return to the pool.
    ///   - key: The key to associate with the view for future reuse.
    public func enqueueView(_ view: View, forKey key: Key) {
        let id = ObjectIdentifier(view)
        let activeKey = viewToKey[id] ?? key
        checkedOut.remove(id)
        viewToKey.removeValue(forKey: id)
        activeViews.removeValue(forKey: activeKey)
        view.removeFromSuperview()
        prepareForReuse(view)
        available[key, default: []].append(view)
    }

    /// Removes all checked-out views from tracking. Does not enqueue them
    /// for reuse — use when the owning view is being torn down.
    public func removeAllCheckedOut() {
        checkedOut.removeAll()
        viewToKey.removeAll()
        activeViews.removeAll()
    }

    /// Removes all views from the pool and resets statistics.
    /// Does not affect checked-out views.
    public func clearPool() {
        available.removeAll()
    }

    /// Removes all views (pooled and tracked). Call during deinit or
    /// when the owning view is removed from the hierarchy.
    public func reset() {
        available.removeAll()
        checkedOut.removeAll()
        viewToKey.removeAll()
        activeViews.removeAll()
    }

    // MARK: - Private

    private func dequeueAvailableView(preferredKey key: Key) -> View? {
        if var views = available[key], !views.isEmpty {
            let view = views.removeLast()
            available[key] = views.isEmpty ? nil : views
            return view
        }

        guard let fallbackKey = available.first(where: { !$0.value.isEmpty })?.key,
              var fallbackViews = available[fallbackKey],
              !fallbackViews.isEmpty else {
            return nil
        }

        let view = fallbackViews.removeLast()
        available[fallbackKey] = fallbackViews.isEmpty ? nil : fallbackViews
        return view
    }

    /// Prepare a view for reuse by resetting its transform and alpha.
    /// Subclasses can override this behavior by providing a custom
    /// `prepareForReuse` closure.
    private func prepareForReuse(_ view: View) {
        view.isHidden = true
        #if canImport(AppKit)
        view.alphaValue = 1.0
        view.frame = .zero
        #else
        view.alpha = 1.0
        view.transform = .identity
        #endif
    }
}
