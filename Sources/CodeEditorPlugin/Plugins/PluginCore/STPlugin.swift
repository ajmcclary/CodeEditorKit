import Foundation

// MARK: - STPlugin

@MainActor
public protocol STPlugin {
    associatedtype Coordinator = Void
    typealias Context = PluginContext<Self>
    typealias CoordinatorContext = STPluginCoordinatorContext

    /// Provides an opportunity to setup plugin environment
    func setUp(context: any Context)

    /// Creates an object to coordinate with the text view.
    func makeCoordinator(context: CoordinatorContext) -> Self.Coordinator

    /// Provides an opportunity to perform cleanup after plugin is about to remove.
    func tearDown()
}

extension STPlugin {
    public func tearDown() {
        // Nothing
    }
}

extension STPlugin where Coordinator == Void {
    public func makeCoordinator(context _: CoordinatorContext) -> Coordinator {
        Coordinator()
    }
}
