import Foundation

// MARK: - PluginContext

@MainActor
public protocol PluginContext<Plugin> {
    associatedtype Plugin: STPlugin
    
    var coordinator: Plugin.Coordinator { get }
    var textView: STTextView { get }
    var events: STPluginEvents { get }
}

// MARK: - STPluginContext

public struct STPluginContext<Plugin: STPlugin>: PluginContext {
    public let coordinator: Plugin.Coordinator
    public let textView: STTextView
    public let events: STPluginEvents
}

// MARK: - STPluginCoordinatorContext

public struct STPluginCoordinatorContext {
    public let textView: STTextView
}
