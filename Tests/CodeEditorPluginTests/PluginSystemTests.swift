@testable import CodeEditorPlugin
import XCTest

@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class PluginSystemTests: XCTestCase {
    func testRegisteredCommandPluginLoadsAndExecutesCommand() async throws {
        let manager = PluginManager(
            configuration: EditorConfiguration(),
            languageRegistry: LanguageRegistry(includeBuiltInLanguages: false),
            completionRegistry: CompletionProviderRegistry(languageMetadataRegistry: LanguageMetadataRegistry()),
            eventSystem: UnifiedEventSystem(enableDefaultFilters: false)
        )

        try await manager.registerPlugin(CommandPlugin.self)
        await manager.loadPlugins()

        XCTAssertEqual(manager.loadedPlugins, [CommandPlugin.identifier])
        XCTAssertEqual(manager.failedPlugins, [])
        XCTAssertEqual(manager.availableCommands().map(\.command.identifier), ["test.command"])

        try await manager.executeCommand(commandId: "test.command", from: CommandPlugin.identifier)
        try await manager.deactivatePlugin(identifier: CommandPlugin.identifier)

        XCTAssertFalse(manager.loadedPlugins.contains(CommandPlugin.identifier))
    }
}

@available(macOS 13.0, iOS 16.0, *)
private final class CommandPlugin: Plugin {
    static let identifier = "com.codeeditorplugin.tests.command"

    let metadata = PluginMetadata(
        identifier: CommandPlugin.identifier,
        name: "Command Test Plugin",
        version: "1.0.0",
        author: "CodeEditorPlugin Tests",
        description: "Registers a command for plugin system coverage.",
        capabilities: [.commands]
    )

    required init() {}

    func activate(context: PluginContext) async throws {
        try await context.registerCommand(
            PluginCommand(identifier: "test.command", title: "Test Command")
        ) {}
    }

    func deactivate(context _: PluginContext) async throws {}
}
