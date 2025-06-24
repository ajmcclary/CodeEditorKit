// MARK: - Plugin

struct Plugin {
    let instance: any STPlugin
    var events: STPluginEvents?

    /// Whether plugin is already setup
    var isSetup: Bool {
        events != nil
    }
}

extension [Plugin] {
    var events: [STPluginEvents] {
        compactMap(\.events)
    }
}
