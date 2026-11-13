import CodeEditorConfiguration
import CodeEditorLanguages
import CodeEditorView
import DesignKitThemes

/// Value state used to decide whether a SwiftUI render requires view mutation.
struct EditorRenderState: Equatable {
    let text: String
    let language: Language
    let configuration: EditorConfiguration
    let theme: Theme
    let runtimeDependencies: EditorRuntimeDependencies

    private let runtimeSnapshot: EditorRuntimeSnapshot

    @MainActor
    init(
        text: String,
        language: Language,
        configuration: EditorConfiguration,
        theme: Theme,
        runtimeDependencies: EditorRuntimeDependencies
    ) {
        self.text = text
        self.language = language
        self.configuration = configuration
        self.theme = theme
        self.runtimeDependencies = runtimeDependencies
        self.runtimeSnapshot = EditorRuntimeSnapshot(runtimeDependencies)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text
            && lhs.language == rhs.language
            && lhs.configuration == rhs.configuration
            && lhs.theme == rhs.theme
            && lhs.runtimeSnapshot == rhs.runtimeSnapshot
    }
}

/// Platform operation boundary used by render reconciliation.
@MainActor
protocol EditorRenderOperating: AnyObject {
    func applyRuntime(
        _ dependencies: EditorRuntimeDependencies,
        to container: CodeEditorContainerView
    )
    func text(in container: CodeEditorContainerView) -> String
    func setText(
        _ text: String,
        in container: CodeEditorContainerView,
        preserveSelection: Bool
    )
    func setLanguage(_ language: Language, in container: CodeEditorContainerView)
    func applySystemColorsIfNeeded(in container: CodeEditorContainerView)
    func setConfiguration(
        _ configuration: EditorConfiguration,
        in container: CodeEditorContainerView
    )
    func stampThemeForeground(in container: CodeEditorContainerView)
    func discardUndoHistory(in container: CodeEditorContainerView)
    func applyTheme(_ theme: Theme, to container: CodeEditorContainerView)
    func invalidate(_ container: CodeEditorContainerView)
}

@MainActor
private final class PlatformEditorRenderOperations: EditorRenderOperating {
    private let platformAdapter = CodeEditorPlatformAdapterFactory.make()

    func applyRuntime(
        _ dependencies: EditorRuntimeDependencies,
        to container: CodeEditorContainerView
    ) {
        container.textView.apply(runtimeDependencies: dependencies)
    }

    func text(in container: CodeEditorContainerView) -> String {
        platformAdapter.text(from: container.textView)
    }

    func setText(
        _ text: String,
        in container: CodeEditorContainerView,
        preserveSelection: Bool
    ) {
        platformAdapter.setText(
            text,
            in: container.textView,
            preserveSelection: preserveSelection
        )
    }

    func setLanguage(_ language: Language, in container: CodeEditorContainerView) {
        guard container.textView.language != language else { return }
        container.textView.language = language
    }

    func applySystemColorsIfNeeded(in container: CodeEditorContainerView) {
        guard container.textView.appliedTheme == nil else { return }
        platformAdapter.applySystemEditorColors(to: container.textView)
    }

    func setConfiguration(
        _ configuration: EditorConfiguration,
        in container: CodeEditorContainerView
    ) {
        guard container.configuration != configuration else { return }
        container.configuration = configuration
    }

    func stampThemeForeground(in container: CodeEditorContainerView) {
        container.textView.stampThemeForeground()
    }

    func discardUndoHistory(in container: CodeEditorContainerView) {
        container.textView.discardUndoHistory()
    }

    func applyTheme(_ theme: Theme, to container: CodeEditorContainerView) {
        container.apply(theme: theme)
    }

    func invalidate(_ container: CodeEditorContainerView) {
        platformAdapter.invalidateLayoutAndDisplay(for: container.textView)
    }
}

/// Applies mount and update operations in one explicit, testable order.
@MainActor
final class EditorRenderReconciler {
    typealias CompletionClosure = CompletionModifierRegistry.CompletionClosure
    typealias StateUpdate = (String, Language, EditorConfiguration) -> Void

    private let operations: any EditorRenderOperating
    private let interactionSynchronizer: EditorInteractionSynchronizer
    private let completionRegistry: CompletionModifierRegistry
    private let bindingSynchronizer: EditorBindingSynchronizer?
    private var lastState: EditorRenderState?

    init(
        operations: (any EditorRenderOperating)? = nil,
        interactionSynchronizer: EditorInteractionSynchronizer = EditorInteractionSynchronizer(),
        completionRegistry: CompletionModifierRegistry = CompletionModifierRegistry(),
        bindingSynchronizer: EditorBindingSynchronizer? = nil
    ) {
        self.operations = operations ?? PlatformEditorRenderOperations()
        self.interactionSynchronizer = interactionSynchronizer
        self.completionRegistry = completionRegistry
        self.bindingSynchronizer = bindingSynchronizer
    }

    func mount(
        _ state: EditorRenderState,
        in container: CodeEditorContainerView,
        completion: CompletionClosure? = nil,
        onStateUpdate: StateUpdate? = nil
    ) {
        operations.applyRuntime(state.runtimeDependencies, to: container)
        operations.setText(state.text, in: container, preserveSelection: false)
        interactionSynchronizer.installBaseline(state.text)
        operations.setLanguage(state.language, in: container)
        operations.applySystemColorsIfNeeded(in: container)
        operations.setConfiguration(state.configuration, in: container)
        updateHardwareState(from: state.configuration)
        interactionSynchronizer.receiveText(state.text, language: state.language)
        completionRegistry.reconcile(
            on: container.textView.completionManager,
            closure: completion
        )
        operations.applyTheme(state.theme, to: container)
        operations.invalidate(container)
        onStateUpdate?(state.text, state.language, state.configuration)
        lastState = state
    }

    @discardableResult
    func update(
        _ state: EditorRenderState,
        in container: CodeEditorContainerView,
        completion: CompletionClosure? = nil,
        onStateUpdate: StateUpdate? = nil
    ) -> Bool {
        operations.applyRuntime(state.runtimeDependencies, to: container)
        completionRegistry.reconcile(
            on: container.textView.completionManager,
            closure: completion
        )
        guard lastState != state else { return false }

        // The host replaced the text only if its text changed since the last
        // render and is not a value the editor itself sent toward it. The
        // binding write is debounced, so host text that is merely behind the
        // editor (unchanged, or an echo of an earlier editor value) must not
        // overwrite newer typing.
        let storedText = operations.text(in: container)
        let hostTextChanged = lastState.map { $0.text != state.text } ?? true
        let isHostBindingSwap = storedText != state.text
            && hostTextChanged
            && !(bindingSynchronizer?.isEditorEcho(state.text) ?? false)
        let effectiveText = isHostBindingSwap ? state.text : storedText
        if isHostBindingSwap {
            operations.setText(state.text, in: container, preserveSelection: true)
            interactionSynchronizer.installBaseline(state.text)
            operations.stampThemeForeground(in: container)
            // Undo offsets recorded against the replaced text would raise or
            // splice old text into the new document.
            operations.discardUndoHistory(in: container)
        }
        operations.setLanguage(state.language, in: container)
        operations.applySystemColorsIfNeeded(in: container)
        operations.setConfiguration(state.configuration, in: container)
        interactionSynchronizer.receiveText(effectiveText, language: state.language)
        operations.applyTheme(state.theme, to: container)
        onStateUpdate?(effectiveText, state.language, state.configuration)
        lastState = state
        return true
    }

    private func updateHardwareState(from configuration: EditorConfiguration) {
        #if canImport(AppKit)
        let isActive = configuration.performance.useHardwareAcceleration
        #else
        let isActive = true
        #endif
        interactionSynchronizer.setHardwareAccelerationActive(isActive)
    }
}
