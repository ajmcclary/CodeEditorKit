# CodeEditorSample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `CodeEditorSample` macOS executable that boots into a single window exercising every public surface added in sub-projects 1–4 — chrome primitives, both Style protocols, the Liquid Glass surface, the bundled themes, and the full `EditorConfiguration` knob set — without any filesystem dependency.

**Architecture:** A SwiftUI `@main` `App` wires an `@Observable` `DocumentStore` (tabs + per-tab text) into a vertical `VStack`: `EditorTitleBar` → `EditorTabStrip` (default style) → horizontal split (`EditorSidebarShell` settings / `CodeEditor` / `EditorSidebarShell` inspector) → `EditorStatusBar`. Switchers and ~52 `EditorConfiguration` knob rows fill the settings sidebar's content slot. The inspector renders the live config as Swift via a pure formatter helper. `EditorCommandPalette` overlays on `⌘⇧P` and dispatches every command from a single live-built catalog.

**Tech Stack:** SwiftPM `executableTarget` (Swift 6.3, `.macOS("26.3")`), SwiftUI, AppKit (transitively via `EditorTitleBar` / `EditorSidebarShell`), `CodeEditorDesignTokens`, `CodeEditorPlugin`, `CodeEditorUI`. No new package dependencies.

**Reference:** [`docs/superpowers/specs/2026-05-05-codeeditorsample-design.md`](../specs/2026-05-05-codeeditorsample-design.md)

---

## File Structure

**New files** (under `Sources/CodeEditorSample/`):

| Path | Responsibility |
|---|---|
| `App/CodeEditorSampleApp.swift` | `@main` `App`. WindowGroup, scene config, top-level state injection. |
| `App/RootWindow.swift` | Window-level layout: title bar + tab strip + body + status bar. Owns sidebar visibility flags and the command-palette presentation flag. |
| `App/WindowBody.swift` | Horizontal split: settings sidebar | editor | inspector sidebar. |
| `Documents/DocumentStore.swift` | `@Observable` class. Owns `tabs: [TabModel]`, `texts: [TabModel.ID: String]`, `activeTabID`. Methods for new/close/closeAll/setActive plus `binding(for:)`. |
| `Switchers/ThemeCatalog.swift` | The 20 bundled `zed-trek` themes, indexed by `Theme.name`. Default = `Theme.lcarsDark`. |
| `Switchers/LanguageCatalog.swift` | `Language.allCases` sorted by display name. |
| `Switchers/PresetCatalog.swift` | Six demo presets — `.default`, `.minimal`, `.readOnly`, `.markdown`, `.presentation`, `.macOS` — each as `(name: String, configuration: EditorConfiguration)`. |
| `Switchers/SwitcherSection.swift` | Three `Picker` rows: Theme, Language, Preset. Sits at the top of the settings sidebar. |
| `KnobPanels/KnobRow.swift` | Reusable row primitives — `ToggleRow`, `StepperRow`, `SliderRow`, `PickerRow`, `ColorRow`, `CharSetRow`, `DurationRow`. |
| `KnobPanels/DisplayKnobsSection.swift` | `DisclosureGroup` with 11 Display knob rows. |
| `KnobPanels/LayoutKnobsSection.swift` | `DisclosureGroup` with 13 Layout knob rows. |
| `KnobPanels/BehaviorKnobsSection.swift` | `DisclosureGroup` with 18 Behavior knob rows. |
| `KnobPanels/PerformanceKnobsSection.swift` | `DisclosureGroup` with 10 Performance knob rows. |
| `Sidebars/SettingsSidebar.swift` | `EditorSidebarShell` wrapper hosting `SwitcherSection` + four knob sections. |
| `Sidebars/InspectorSidebar.swift` | `EditorSidebarShell` wrapper rendering live config + Copy button. |
| `Sidebars/ConfigurationCodeFormatter.swift` | Pure helper. `EditorConfiguration` → Swift source string (only fields that differ from defaults). |
| `CommandPalette/CommandPaletteCatalog.swift` | Builds `[CommandPaletteItem]` + dispatch closure from the live state. |

**Modified files:**
- `Package.swift` — adds the `executableTarget` for `CodeEditorSample`.
- `CHANGELOG.md` — adds a sub-project 5 entry on the final task.

**No new test target.** The spec explicitly defers a `CodeEditorSampleTests` target. Each task verifies via `swift build`, `swiftlint`, `swift test --parallel` (existing 187 tests stay green), and `swift run CodeEditorSample` smoke checks called out per task.

---

## Task 1: Package skeleton + `@main` shell

Add the executable target. The first run only needs to open an empty window — no content, no chrome. This proves the wiring builds.

**Files:**
- Modify: `Package.swift:71-138` (insert new target inside `targets:` array; insert new product inside `products:`)
- Create: `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`

- [ ] **Step 1: Add the executable product and target to `Package.swift`**

Modify `Package.swift`. In the `products:` array, add a new entry alongside the existing three libraries:

```swift
.executable(
    name: "CodeEditorSample",
    targets: ["CodeEditorSample"]
)
```

In the `targets:` array, add a new target after `CodeEditorUI` and before the test targets:

```swift
.executableTarget(
    name: "CodeEditorSample",
    dependencies: [
        "CodeEditorDesignTokens",
        "CodeEditorPlugin",
        "CodeEditorUI"
    ],
    swiftSettings: swiftSettings
),
```

- [ ] **Step 2: Create the minimal `@main` app file**

Create `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`:

```swift
import SwiftUI

@main
struct CodeEditorSampleApp: App {
    var body: some Scene {
        WindowGroup("CodeEditorSample") {
            Text("CodeEditorSample — boot")
                .frame(minWidth: 980, minHeight: 640)
                .frame(width: 1380, height: 880)
        }
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Smoke-run the empty shell**

Run: `swift run CodeEditorSample`
Expected: a window appears titled `"CodeEditorSample"` containing the text `"CodeEditorSample — boot"`. Close the window or `Ctrl-C` to exit.

- [ ] **Step 5: SwiftLint and existing tests**

Run: `swiftlint && swift test --parallel`
Expected: `Done linting! Found 0 violations…` and `187 tests in 48 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/CodeEditorSample/App/CodeEditorSampleApp.swift
git commit -m "Sample: scaffold CodeEditorSample executableTarget

Empty SwiftUI App that opens a 1380x880 window. Adds the executable
product to Package.swift; depends on the three library products.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: DocumentStore

Owns the tab list and per-tab text contents. Single source of truth for everything the editor and tab strip read.

**Files:**
- Create: `Sources/CodeEditorSample/Documents/DocumentStore.swift`

- [ ] **Step 1: Create `DocumentStore.swift`**

```swift
import CodeEditorPlugin
import Foundation
import Observation
import SwiftUI

/// Multi-tab in-memory document store for the sample app. Owns the
/// canonical `[TabModel]` consumed by `EditorTabStrip` and a per-tab
/// text dictionary. No persistence — `⌘S` is a no-op in the demo.
@MainActor
@Observable
final class DocumentStore {
    /// Tabs in display order. `EditorTabStrip` binds to a derived
    /// binding into this array.
    var tabs: [TabModel]

    /// Active tab; nil when `tabs.isEmpty`.
    var activeTabID: TabModel.ID?

    /// Per-tab text contents, keyed by `TabModel.id`.
    private var texts: [TabModel.ID: String]

    /// Counter for `Untitled-N.swift` naming.
    private var untitledCounter: Int

    /// Boot state: one empty `Untitled-1.swift` tab, active.
    init() {
        let first = TabModel(name: "Untitled-1.swift", language: .swift)
        self.tabs = [first]
        self.activeTabID = first.id
        self.texts = [first.id: ""]
        self.untitledCounter = 1
    }

    // MARK: - Tab lifecycle

    /// Append a new `Untitled-N.swift` tab and activate it.
    func newTab() {
        untitledCounter += 1
        let tab = TabModel(name: "Untitled-\(untitledCounter).swift", language: .swift)
        tabs.append(tab)
        texts[tab.id] = ""
        activeTabID = tab.id
    }

    /// Close a tab. If the closed tab was active, activate the previous
    /// tab in the list, or `nil` when the list becomes empty.
    func close(_ id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        texts.removeValue(forKey: id)
        if activeTabID == id {
            activeTabID = index > 0 ? tabs[index - 1].id : tabs.first?.id
        }
    }

    /// Close every tab.
    func closeAll() {
        tabs.removeAll()
        texts.removeAll()
        activeTabID = nil
    }

    /// Activate a tab by id. No-op if `id` isn't in `tabs`.
    func setActive(_ id: TabModel.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    // MARK: - Per-tab content access

    /// Text binding for a given tab id. Reads return the empty string
    /// for unknown ids. Writes mark the tab dirty when the new value
    /// differs from the previous.
    func textBinding(for id: TabModel.ID) -> Binding<String> {
        Binding(
            get: { self.texts[id] ?? "" },
            set: { newValue in
                let oldValue = self.texts[id] ?? ""
                self.texts[id] = newValue
                if oldValue != newValue,
                   let index = self.tabs.firstIndex(where: { $0.id == id }),
                   !self.tabs[index].isDirty {
                    self.tabs[index].isDirty = true
                }
            }
        )
    }

    /// Set the language of a tab in-place. No-op for unknown ids.
    func setLanguage(_ language: Language, of id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
    }

    /// Convenience: the language of the active tab, or nil.
    var activeLanguage: Language? {
        guard let activeTabID,
              let tab = tabs.first(where: { $0.id == activeTabID })
        else { return nil }
        return tab.language
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Documents/DocumentStore.swift
git commit -m "Sample: DocumentStore — in-memory tabs + per-tab text

@Observable @MainActor class. Owns [TabModel] for the chrome plus a
[TabModel.ID: String] text dictionary. newTab/close/closeAll/setActive,
textBinding(for:), and setLanguage. Boot state: one empty
Untitled-1.swift tab, active.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Switcher catalogs

Three pure-data catalogs feeding the switcher row pickers.

**Files:**
- Create: `Sources/CodeEditorSample/Switchers/ThemeCatalog.swift`
- Create: `Sources/CodeEditorSample/Switchers/LanguageCatalog.swift`
- Create: `Sources/CodeEditorSample/Switchers/PresetCatalog.swift`

- [ ] **Step 1: Create `ThemeCatalog.swift`**

```swift
import CodeEditorPlugin
import Foundation

/// Bundled-theme catalog for the sample app's theme picker. Reads the
/// 20 `zed-trek` variants once at first access; lookup is O(1) by name.
enum ThemeCatalog {
    static let all: [Theme] = {
        guard let family = ThemeFamily.bundled("zed-trek") else { return [] }
        return family.themes
    }()

    /// Default on launch — `LCARS Dark` from the bundled `zed-trek`
    /// family (same `Theme` value as `Theme.lcarsDark`).
    static let `default`: Theme = .lcarsDark

    /// Look up a theme by display name; returns `default` on miss.
    static func theme(named name: String) -> Theme {
        all.first { $0.name == name } ?? `default`
    }
}
```

- [ ] **Step 2: Create `LanguageCatalog.swift`**

```swift
import CodeEditorPlugin
import Foundation

/// Display-name-sorted list of `Language` cases for the language picker.
enum LanguageCatalog {
    static let all: [Language] = Language.allCases.sorted { $0.name < $1.name }

    /// Default for new tabs.
    static let `default`: Language = .swift
}
```

- [ ] **Step 3: Create `PresetCatalog.swift`**

```swift
import CodeEditorPlugin
import Foundation

/// Six demo presets exposed by the sample's preset picker. iOS- and
/// Catalyst-optimized presets are intentionally omitted — they're
/// platform-optimized variants whose effects don't read on a macOS demo.
struct ConfigurationPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let configuration: EditorConfiguration

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PresetCatalog {
    static let all: [ConfigurationPreset] = [
        ConfigurationPreset(id: "default",      name: "Default",      configuration: .default),
        ConfigurationPreset(id: "minimal",      name: "Minimal",      configuration: .minimal),
        ConfigurationPreset(id: "readOnly",     name: "Read-only",    configuration: .readOnly),
        ConfigurationPreset(id: "markdown",     name: "Markdown",     configuration: .markdown),
        ConfigurationPreset(id: "presentation", name: "Presentation", configuration: .presentation),
        ConfigurationPreset(id: "macOS",        name: "macOS",        configuration: .macOS)
    ]

    /// Default on launch.
    static let `default`: ConfigurationPreset = all.first(where: { $0.id == "default" }) ?? all[0]
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/Switchers/
git commit -m "Sample: switcher catalogs — themes, languages, presets

ThemeCatalog reads zed-trek's 20 variants once at static init.
LanguageCatalog sorts Language.allCases by display name. PresetCatalog
wraps six EditorConfiguration presets in an Identifiable struct so the
Picker can bind by id.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: SwitcherSection — three Picker rows

The three pickers that sit above the knob playground in the settings sidebar.

**Files:**
- Create: `Sources/CodeEditorSample/Switchers/SwitcherSection.swift`

- [ ] **Step 1: Create `SwitcherSection.swift`**

```swift
import CodeEditorPlugin
import SwiftUI

/// Three Picker rows wired to environment + DocumentStore + binding.
/// Sits at the top of the settings sidebar above the knob playground.
struct SwitcherSection: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            themePicker
            languagePicker
            presetPicker
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Theme").font(.system(size: 11, weight: .semibold))
            Picker("Theme", selection: themeBinding) {
                ForEach(ThemeCatalog.all, id: \.name) { theme in
                    Text(theme.name).tag(theme.name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Language").font(.system(size: 11, weight: .semibold))
            Picker("Language", selection: languageBinding) {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Text(language.name).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(documents.activeTabID == nil)
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preset").font(.system(size: 11, weight: .semibold))
            Picker("Preset", selection: presetBinding) {
                ForEach(PresetCatalog.all) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: - Bindings

    private var themeBinding: Binding<String> {
        Binding(
            get: { theme.name },
            set: { theme = ThemeCatalog.theme(named: $0) }
        )
    }

    private var languageBinding: Binding<Language> {
        Binding(
            get: { documents.activeLanguage ?? LanguageCatalog.default },
            set: { newValue in
                guard let id = documents.activeTabID else { return }
                documents.setLanguage(newValue, of: id)
            }
        )
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: {
                PresetCatalog.all.first(where: { $0.configuration == configuration })?.id
                    ?? PresetCatalog.default.id
            },
            set: { newID in
                if let preset = PresetCatalog.all.first(where: { $0.id == newID }) {
                    configuration = preset.configuration
                }
            }
        )
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Switchers/SwitcherSection.swift
git commit -m "Sample: SwitcherSection — three Picker rows

Theme / Language / Preset pickers wired by name (theme), enum (language),
and preset id. Theme binding rewrites Theme via ThemeCatalog.theme(named:).
Preset binding does an EditorConfiguration == comparison to detect the
'Custom' state implicitly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Knob row primitives

Reusable SwiftUI rows for every knob type. Pure presentation; bindings come from outside.

**Files:**
- Create: `Sources/CodeEditorSample/KnobPanels/KnobRow.swift`

- [ ] **Step 1: Create `KnobRow.swift`**

```swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

// MARK: - Toggle

struct ToggleRow: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        Toggle(isOn: $value) { Text(label).font(.system(size: 11)) }
            .toggleStyle(.switch)
            .controlSize(.mini)
    }
}

// MARK: - Stepper (Int)

struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            Stepper(value: $value, in: range, step: step) {
                Text("\(value)").font(.system(size: 11, design: .monospaced))
            }
            .controlSize(.mini)
            .labelsHidden()
            Text("\(value)").font(.system(size: 11, design: .monospaced)).frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - Slider (Double)

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 11))
                Spacer()
                Text(value, format: format).font(.system(size: 11, design: .monospaced))
            }
            if step > 0 {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }
}

// MARK: - Slider (CGFloat — bridge through Double)

struct CGFloatSliderRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var step: CGFloat = 0
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        SliderRow(
            label: label,
            value: Binding(get: { Double(value) }, set: { value = CGFloat($0) }),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            format: format
        )
    }
}

// MARK: - Picker (generic)

struct PickerRow<T: Hashable & Sendable>: View {
    let label: String
    @Binding var value: T
    let cases: [T]
    let display: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold))
            Picker(label, selection: $value) {
                ForEach(cases, id: \.self) { item in
                    Text(display(item)).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Color (PlatformColor)

struct ColorRow: View {
    let label: String
    @Binding var value: PlatformColor

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            ColorPicker(label, selection: bridgedBinding, supportsOpacity: true)
                .labelsHidden()
        }
    }

    private var bridgedBinding: Binding<Color> {
        Binding(
            get: { Color(platformColor: value) },
            set: { value = PlatformColor(swiftUI: $0) }
        )
    }
}

// MARK: - Char-set (Set<Character>)

struct CharSetRow: View {
    let label: String
    @Binding var value: Set<Character>
    @State private var editing: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold))
            TextField("comma-separated", text: $editing)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }
                .onAppear { editing = render(value) }
                .onChange(of: value) { _, newValue in editing = render(newValue) }
        }
    }

    private func commit() {
        let parsed = editing
            .split(separator: ",")
            .compactMap { token -> Character? in
                let trimmed = token.trimmingCharacters(in: .whitespaces)
                return trimmed.first
            }
        value = Set(parsed)
    }

    private func render(_ set: Set<Character>) -> String {
        set.map { String($0) }.sorted().joined(separator: ",")
    }
}

// MARK: - Duration

struct DurationRow: View {
    let label: String
    @Binding var value: Duration
    let rangeMS: ClosedRange<Double>

    var body: some View {
        SliderRow(
            label: label,
            value: Binding(
                get: { Self.milliseconds(value) },
                set: { value = .milliseconds(Int($0)) }
            ),
            range: rangeMS,
            step: 1,
            format: .number.precision(.fractionLength(0))
        )
    }

    /// Duration → milliseconds as Double.
    private static func milliseconds(_ duration: Duration) -> Double {
        let attos = duration.components.attoseconds
        let seconds = Double(duration.components.seconds)
        return seconds * 1000 + Double(attos) / 1_000_000_000_000_000
    }
}

// MARK: - Helpers — Color ↔ PlatformColor bridge

#if canImport(AppKit)
private extension Color {
    init(platformColor: PlatformColor) { self.init(nsColor: platformColor) }
}

private extension PlatformColor {
    convenience init(swiftUI color: Color) {
        self.init(color)
    }
}
#elseif canImport(UIKit)
private extension Color {
    init(platformColor: PlatformColor) { self.init(uiColor: platformColor) }
}

private extension PlatformColor {
    convenience init(swiftUI color: Color) {
        self.init(color)
    }
}
#endif
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/KnobPanels/KnobRow.swift
git commit -m "Sample: knob row primitives

Reusable rows: ToggleRow, StepperRow (Int), SliderRow (Double),
CGFloatSliderRow (bridges through Double), PickerRow<T>, ColorRow
(PlatformColor <-> SwiftUI Color), CharSetRow (comma-separated commit
on submit), DurationRow (slider over milliseconds).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Display knobs section

11 rows for every public Display property except DI hooks.

**Files:**
- Create: `Sources/CodeEditorSample/KnobPanels/DisplayKnobsSection.swift`

- [ ] **Step 1: Create `DisplayKnobsSection.swift`**

```swift
import CodeEditorPlugin
import SwiftUI

struct DisplayKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = true

    var body: some View {
        DisclosureGroup("Display", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                CGFloatSliderRow(label: "fontSize", value: $configuration.display.fontSize, range: 9...32, step: 1, format: .number.precision(.fractionLength(0)))
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.display.isLineNumbersEnabled)
                ToggleRow(label: "enableAnnotations", value: $configuration.display.enableAnnotations)
                ToggleRow(label: "highlightSelectedLine", value: $configuration.display.highlightSelectedLine)
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.display.selectedLineHighlightColor)
                ToggleRow(label: "showInvisibleCharacters", value: $configuration.display.showInvisibleCharacters)
                ToggleRow(label: "enableCodeFolding", value: $configuration.display.enableCodeFolding)
                ToggleRow(label: "showFoldingControls", value: $configuration.display.showFoldingControls)
                StepperRow(label: "minimumFoldableLines", value: $configuration.display.minimumFoldableLines, range: 1...100)
                ToggleRow(label: "animateCodeFolding", value: $configuration.display.animateCodeFolding)
                ToggleRow(label: "showMinimap", value: $configuration.display.showMinimap)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/KnobPanels/DisplayKnobsSection.swift
git commit -m "Sample: DisplayKnobsSection — 11 knob rows

DisclosureGroup wrapping every user-facing Display knob: font size,
line numbers, annotations, line highlight + color, invisibles, folding
trio + minimumFoldableLines, animateCodeFolding, minimap.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Layout knobs section

13 rows for every public Layout property.

**Files:**
- Create: `Sources/CodeEditorSample/KnobPanels/LayoutKnobsSection.swift`

- [ ] **Step 1: Create `LayoutKnobsSection.swift`**

```swift
import CodeEditorPlugin
import SwiftUI

struct LayoutKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Layout", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: "tabWidth", value: $configuration.layout.tabWidth, range: 1...8)
                ToggleRow(label: "insertSpacesForTabs", value: $configuration.layout.insertSpacesForTabs)
                ToggleRow(label: "wrapLines", value: $configuration.layout.wrapLines)
                CGFloatSliderRow(label: "gutterWidth", value: $configuration.layout.gutterWidth, range: 0...80, step: 0.5)
                CGFloatSliderRow(label: "lineNumberPadding", value: $configuration.layout.lineNumberPadding, range: 0...40, step: 0.5)
                CGFloatSliderRow(label: "lineHeightMultiple", value: $configuration.layout.lineHeightMultiple, range: 0.0...2.0, step: 0.05)
                CGFloatSliderRow(label: "characterSpacing", value: $configuration.layout.characterSpacing, range: 0.0...4.0, step: 0.05)
                CGFloatSliderRow(label: "textContainerWidthFraction", value: $configuration.layout.textContainerWidthFraction, range: 0.5...1.0, step: 0.05)
                CGFloatSliderRow(label: "annotationBadgeSize", value: $configuration.layout.annotationBadgeSize, range: 6...32, step: 0.5)
                CGFloatSliderRow(label: "annotationBadgePadding", value: $configuration.layout.annotationBadgePadding, range: 0...16, step: 0.5)
                CGFloatSliderRow(label: "minimapWidth", value: $configuration.layout.minimapWidth, range: 40...240, step: 1)
                CGFloatSliderRow(label: "foldingControlSize", value: $configuration.layout.foldingControlSize, range: 6...24, step: 0.5)
                CGFloatSliderRow(label: "foldingControlPadding", value: $configuration.layout.foldingControlPadding, range: 0...12, step: 0.5)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/KnobPanels/LayoutKnobsSection.swift
git commit -m "Sample: LayoutKnobsSection — 13 knob rows

DisclosureGroup wrapping every user-facing Layout knob: tab width +
spaces, wrap, gutter width + line-number padding, line-height multiple,
character spacing, container-width fraction, annotation/folding-control
sizes + paddings, minimap width.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Behavior knobs section

18 rows for every public Behavior property.

**Files:**
- Create: `Sources/CodeEditorSample/KnobPanels/BehaviorKnobsSection.swift`

- [ ] **Step 1: Create `BehaviorKnobsSection.swift`**

```swift
import CodeEditorPlugin
import SwiftUI

struct BehaviorKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Behavior", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                ToggleRow(label: "isEditable", value: $configuration.behavior.isEditable)
                ToggleRow(label: "isSelectable", value: $configuration.behavior.isSelectable)
                ToggleRow(label: "autoIndent", value: $configuration.behavior.autoIndent)
                ToggleRow(label: "enableCodeCompletion", value: $configuration.behavior.enableCodeCompletion)
                ToggleRow(label: "isAutomaticLinkDetectionEnabled", value: $configuration.behavior.isAutomaticLinkDetectionEnabled)
                ToggleRow(label: "isAutomaticQuoteSubstitutionEnabled", value: $configuration.behavior.isAutomaticQuoteSubstitutionEnabled)
                ToggleRow(label: "isAutomaticDashSubstitutionEnabled", value: $configuration.behavior.isAutomaticDashSubstitutionEnabled)
                ToggleRow(label: "autoCloseBrackets", value: $configuration.behavior.autoCloseBrackets)
                ToggleRow(label: "autoCloseQuotes", value: $configuration.behavior.autoCloseQuotes)
                ToggleRow(label: "isContinuousSpellCheckingEnabled", value: $configuration.behavior.isContinuousSpellCheckingEnabled)
                ToggleRow(label: "isGrammarCheckingEnabled", value: $configuration.behavior.isGrammarCheckingEnabled)
                ToggleRow(label: "isAutomaticTextReplacementEnabled", value: $configuration.behavior.isAutomaticTextReplacementEnabled)
                ToggleRow(label: "isAutomaticSpellingCorrectionEnabled", value: $configuration.behavior.isAutomaticSpellingCorrectionEnabled)
                ToggleRow(label: "isAutomaticTextCompletionEnabled", value: $configuration.behavior.isAutomaticTextCompletionEnabled)
                ToggleRow(label: "showInlineCompletionSuggestions", value: $configuration.behavior.showInlineCompletionSuggestions)
                CharSetRow(label: "completionTriggerCharacters", value: $configuration.behavior.completionTriggerCharacters)
                ToggleRow(label: "autoScrollToCursor", value: $configuration.behavior.autoScrollToCursor)
                ToggleRow(label: "enableSyntaxHighlighting", value: $configuration.behavior.enableSyntaxHighlighting)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/KnobPanels/BehaviorKnobsSection.swift
git commit -m "Sample: BehaviorKnobsSection — 18 knob rows

DisclosureGroup wrapping every user-facing Behavior knob: editable,
selectable, auto-indent, completion + inline suggestions + trigger-set,
auto-close brackets/quotes, every macOS automatic-text toggle,
spell/grammar, auto-scroll, syntax highlighting.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Performance knobs section

10 rows for every macOS-relevant Performance property.

**Files:**
- Create: `Sources/CodeEditorSample/KnobPanels/PerformanceKnobsSection.swift`

- [ ] **Step 1: Create `PerformanceKnobsSection.swift`**

```swift
import CodeEditorPlugin
import SwiftUI

struct PerformanceKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Performance", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: "maxSyntaxHighlightingLength", value: $configuration.performance.maxSyntaxHighlightingLength, range: 1024...10_485_760, step: 1024)
                ToggleRow(label: "useHardwareAcceleration", value: $configuration.performance.useHardwareAcceleration)
                PickerRow(
                    label: "renderingUpdateStrategy",
                    value: $configuration.performance.renderingUpdateStrategy,
                    cases: [.adaptive, .immediate, .batched],
                    display: { String(describing: $0) }
                )
                StepperRow(label: "maxVisibleLines", value: $configuration.performance.maxVisibleLines, range: 1...100_000, step: 100)
                StepperRow(label: "maxFileSize", value: $configuration.performance.maxFileSize, range: 0...100_000_000, step: 1024)
                DurationRow(label: "highlightingDebounceInterval", value: $configuration.performance.highlightingDebounceInterval, rangeMS: 0...1000)
                ToggleRow(label: "smoothScrolling", value: $configuration.performance.smoothScrolling)
                DurationRow(label: "textChangeDebounceInterval", value: $configuration.performance.textChangeDebounceInterval, rangeMS: 0...1000)
                ToggleRow(label: "animateCodeFolding (perf)", value: $configuration.performance.animateCodeFolding)
                StepperRow(label: "maxEventsPerSecond", value: $configuration.performance.maxEventsPerSecond, range: 1...240)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/KnobPanels/PerformanceKnobsSection.swift
git commit -m "Sample: PerformanceKnobsSection — 10 knob rows

DisclosureGroup wrapping every macOS-relevant Performance knob:
maxSyntaxHighlightingLength, hardware accel, renderingUpdateStrategy
picker (.adaptive/.immediate/.batched), maxVisibleLines, maxFileSize,
both Duration debounce sliders, smoothScrolling, animateCodeFolding,
maxEventsPerSecond. iOS-only knobs deliberately omitted.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: SettingsSidebar — assemble switchers + knobs

Wire SwitcherSection + four DisclosureGroup sections inside an `EditorSidebarShell`.

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift`

- [ ] **Step 1: Create `SettingsSidebar.swift`**

```swift
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Left sidebar shell: switchers on top, four knob sections below.
struct SettingsSidebar: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Settings",
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SwitcherSection(
                            theme: $theme,
                            configuration: $configuration,
                            documents: documents
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            DisplayKnobsSection(configuration: $configuration)
                            LayoutKnobsSection(configuration: $configuration)
                            BehaviorKnobsSection(configuration: $configuration)
                            PerformanceKnobsSection(configuration: $configuration)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.bottom, 12)
                }
            }
        )
        .frame(width: 280)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift
git commit -m "Sample: SettingsSidebar — assemble switchers + four knob sections

EditorSidebarShell wrapper, sectionTitle 'Settings'. Content slot
scrolls a vertical stack: SwitcherSection on top, four
DisclosureGroup knob sections below.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: ConfigurationCodeFormatter

Pure helper turning the live `EditorConfiguration` into Swift source. Only emits fields that differ from the default.

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/ConfigurationCodeFormatter.swift`

- [ ] **Step 1: Create `ConfigurationCodeFormatter.swift`**

```swift
import CodeEditorPlugin
import Foundation

/// Renders an `EditorConfiguration` as Swift source — direct property
/// assignments grouped by section. Only fields that differ from the
/// default `EditorConfiguration()` are emitted, to keep the output
/// scannable.
///
/// Pure value-in / string-out — easy to inspect from the inspector
/// sidebar.
enum ConfigurationCodeFormatter {
    static func render(_ configuration: EditorConfiguration) -> String {
        let baseline = EditorConfiguration()
        var sections: [(title: String, lines: [String])] = []

        sections.append(("Display", displayLines(configuration, baseline: baseline)))
        sections.append(("Layout", layoutLines(configuration, baseline: baseline)))
        sections.append(("Behavior", behaviorLines(configuration, baseline: baseline)))
        sections.append(("Performance", performanceLines(configuration, baseline: baseline)))

        var out = "var config = EditorConfiguration()\n"
        for (title, lines) in sections where !lines.isEmpty {
            out += "\n// \(title)\n"
            out += lines.joined(separator: "\n")
            out += "\n"
        }

        if sections.allSatisfy({ $0.lines.isEmpty }) {
            out += "\n// (every knob matches its default)\n"
        }

        return out
    }

    // MARK: - Section helpers

    private static func displayLines(_ live: EditorConfiguration, baseline: EditorConfiguration) -> [String] {
        var lines: [String] = []
        let prefix = "config.display"
        let live = live.display
        let base = baseline.display
        if live.fontSize != base.fontSize { lines.append("\(prefix).fontSize = \(formatCGFloat(live.fontSize))") }
        if live.isLineNumbersEnabled != base.isLineNumbersEnabled { lines.append("\(prefix).isLineNumbersEnabled = \(live.isLineNumbersEnabled)") }
        if live.enableAnnotations != base.enableAnnotations { lines.append("\(prefix).enableAnnotations = \(live.enableAnnotations)") }
        if live.highlightSelectedLine != base.highlightSelectedLine { lines.append("\(prefix).highlightSelectedLine = \(live.highlightSelectedLine)") }
        if live.showInvisibleCharacters != base.showInvisibleCharacters { lines.append("\(prefix).showInvisibleCharacters = \(live.showInvisibleCharacters)") }
        if live.enableCodeFolding != base.enableCodeFolding { lines.append("\(prefix).enableCodeFolding = \(live.enableCodeFolding)") }
        if live.showFoldingControls != base.showFoldingControls { lines.append("\(prefix).showFoldingControls = \(live.showFoldingControls)") }
        if live.minimumFoldableLines != base.minimumFoldableLines { lines.append("\(prefix).minimumFoldableLines = \(live.minimumFoldableLines)") }
        if live.animateCodeFolding != base.animateCodeFolding { lines.append("\(prefix).animateCodeFolding = \(live.animateCodeFolding)") }
        if live.showMinimap != base.showMinimap { lines.append("\(prefix).showMinimap = \(live.showMinimap)") }
        // selectedLineHighlightColor: PlatformColor isn't trivially renderable as Swift literal.
        // Note its presence rather than render the exact value.
        if live.selectedLineHighlightColor != base.selectedLineHighlightColor {
            lines.append("\(prefix).selectedLineHighlightColor = /* custom */")
        }
        return lines
    }

    private static func layoutLines(_ live: EditorConfiguration, baseline: EditorConfiguration) -> [String] {
        var lines: [String] = []
        let prefix = "config.layout"
        let live = live.layout
        let base = baseline.layout
        if live.tabWidth != base.tabWidth { lines.append("\(prefix).tabWidth = \(live.tabWidth)") }
        if live.insertSpacesForTabs != base.insertSpacesForTabs { lines.append("\(prefix).insertSpacesForTabs = \(live.insertSpacesForTabs)") }
        if live.wrapLines != base.wrapLines { lines.append("\(prefix).wrapLines = \(live.wrapLines)") }
        if live.gutterWidth != base.gutterWidth { lines.append("\(prefix).gutterWidth = \(formatCGFloat(live.gutterWidth))") }
        if live.lineNumberPadding != base.lineNumberPadding { lines.append("\(prefix).lineNumberPadding = \(formatCGFloat(live.lineNumberPadding))") }
        if live.lineHeightMultiple != base.lineHeightMultiple { lines.append("\(prefix).lineHeightMultiple = \(formatCGFloat(live.lineHeightMultiple))") }
        if live.characterSpacing != base.characterSpacing { lines.append("\(prefix).characterSpacing = \(formatCGFloat(live.characterSpacing))") }
        if live.textContainerWidthFraction != base.textContainerWidthFraction { lines.append("\(prefix).textContainerWidthFraction = \(formatCGFloat(live.textContainerWidthFraction))") }
        if live.annotationBadgeSize != base.annotationBadgeSize { lines.append("\(prefix).annotationBadgeSize = \(formatCGFloat(live.annotationBadgeSize))") }
        if live.annotationBadgePadding != base.annotationBadgePadding { lines.append("\(prefix).annotationBadgePadding = \(formatCGFloat(live.annotationBadgePadding))") }
        if live.minimapWidth != base.minimapWidth { lines.append("\(prefix).minimapWidth = \(formatCGFloat(live.minimapWidth))") }
        if live.foldingControlSize != base.foldingControlSize { lines.append("\(prefix).foldingControlSize = \(formatCGFloat(live.foldingControlSize))") }
        if live.foldingControlPadding != base.foldingControlPadding { lines.append("\(prefix).foldingControlPadding = \(formatCGFloat(live.foldingControlPadding))") }
        return lines
    }

    private static func behaviorLines(_ live: EditorConfiguration, baseline: EditorConfiguration) -> [String] {
        var lines: [String] = []
        let prefix = "config.behavior"
        let live = live.behavior
        let base = baseline.behavior
        if live.isEditable != base.isEditable { lines.append("\(prefix).isEditable = \(live.isEditable)") }
        if live.isSelectable != base.isSelectable { lines.append("\(prefix).isSelectable = \(live.isSelectable)") }
        if live.autoIndent != base.autoIndent { lines.append("\(prefix).autoIndent = \(live.autoIndent)") }
        if live.enableCodeCompletion != base.enableCodeCompletion { lines.append("\(prefix).enableCodeCompletion = \(live.enableCodeCompletion)") }
        if live.isAutomaticLinkDetectionEnabled != base.isAutomaticLinkDetectionEnabled { lines.append("\(prefix).isAutomaticLinkDetectionEnabled = \(live.isAutomaticLinkDetectionEnabled)") }
        if live.isAutomaticQuoteSubstitutionEnabled != base.isAutomaticQuoteSubstitutionEnabled { lines.append("\(prefix).isAutomaticQuoteSubstitutionEnabled = \(live.isAutomaticQuoteSubstitutionEnabled)") }
        if live.isAutomaticDashSubstitutionEnabled != base.isAutomaticDashSubstitutionEnabled { lines.append("\(prefix).isAutomaticDashSubstitutionEnabled = \(live.isAutomaticDashSubstitutionEnabled)") }
        if live.autoCloseBrackets != base.autoCloseBrackets { lines.append("\(prefix).autoCloseBrackets = \(live.autoCloseBrackets)") }
        if live.autoCloseQuotes != base.autoCloseQuotes { lines.append("\(prefix).autoCloseQuotes = \(live.autoCloseQuotes)") }
        if live.isContinuousSpellCheckingEnabled != base.isContinuousSpellCheckingEnabled { lines.append("\(prefix).isContinuousSpellCheckingEnabled = \(live.isContinuousSpellCheckingEnabled)") }
        if live.isGrammarCheckingEnabled != base.isGrammarCheckingEnabled { lines.append("\(prefix).isGrammarCheckingEnabled = \(live.isGrammarCheckingEnabled)") }
        if live.isAutomaticTextReplacementEnabled != base.isAutomaticTextReplacementEnabled { lines.append("\(prefix).isAutomaticTextReplacementEnabled = \(live.isAutomaticTextReplacementEnabled)") }
        if live.isAutomaticSpellingCorrectionEnabled != base.isAutomaticSpellingCorrectionEnabled { lines.append("\(prefix).isAutomaticSpellingCorrectionEnabled = \(live.isAutomaticSpellingCorrectionEnabled)") }
        if live.isAutomaticTextCompletionEnabled != base.isAutomaticTextCompletionEnabled { lines.append("\(prefix).isAutomaticTextCompletionEnabled = \(live.isAutomaticTextCompletionEnabled)") }
        if live.showInlineCompletionSuggestions != base.showInlineCompletionSuggestions { lines.append("\(prefix).showInlineCompletionSuggestions = \(live.showInlineCompletionSuggestions)") }
        if live.completionTriggerCharacters != base.completionTriggerCharacters {
            let chars = live.completionTriggerCharacters.map { "\"\($0)\"" }.sorted().joined(separator: ", ")
            lines.append("\(prefix).completionTriggerCharacters = [\(chars)]")
        }
        if live.autoScrollToCursor != base.autoScrollToCursor { lines.append("\(prefix).autoScrollToCursor = \(live.autoScrollToCursor)") }
        if live.enableSyntaxHighlighting != base.enableSyntaxHighlighting { lines.append("\(prefix).enableSyntaxHighlighting = \(live.enableSyntaxHighlighting)") }
        return lines
    }

    private static func performanceLines(_ live: EditorConfiguration, baseline: EditorConfiguration) -> [String] {
        var lines: [String] = []
        let prefix = "config.performance"
        let live = live.performance
        let base = baseline.performance
        if live.maxSyntaxHighlightingLength != base.maxSyntaxHighlightingLength { lines.append("\(prefix).maxSyntaxHighlightingLength = \(live.maxSyntaxHighlightingLength)") }
        if live.useHardwareAcceleration != base.useHardwareAcceleration { lines.append("\(prefix).useHardwareAcceleration = \(live.useHardwareAcceleration)") }
        if live.renderingUpdateStrategy != base.renderingUpdateStrategy { lines.append("\(prefix).renderingUpdateStrategy = .\(live.renderingUpdateStrategy)") }
        if live.maxVisibleLines != base.maxVisibleLines { lines.append("\(prefix).maxVisibleLines = \(live.maxVisibleLines)") }
        if live.maxFileSize != base.maxFileSize { lines.append("\(prefix).maxFileSize = \(live.maxFileSize)") }
        if live.highlightingDebounceInterval != base.highlightingDebounceInterval {
            lines.append("\(prefix).highlightingDebounceInterval = .milliseconds(\(durationMilliseconds(live.highlightingDebounceInterval)))")
        }
        if live.smoothScrolling != base.smoothScrolling { lines.append("\(prefix).smoothScrolling = \(live.smoothScrolling)") }
        if live.textChangeDebounceInterval != base.textChangeDebounceInterval {
            lines.append("\(prefix).textChangeDebounceInterval = .milliseconds(\(durationMilliseconds(live.textChangeDebounceInterval)))")
        }
        if live.animateCodeFolding != base.animateCodeFolding { lines.append("\(prefix).animateCodeFolding = \(live.animateCodeFolding)") }
        if live.maxEventsPerSecond != base.maxEventsPerSecond { lines.append("\(prefix).maxEventsPerSecond = \(live.maxEventsPerSecond)") }
        return lines
    }

    // MARK: - Number formatting

    private static func formatCGFloat(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", rounded)
    }

    private static func durationMilliseconds(_ duration: Duration) -> Int {
        let attos = duration.components.attoseconds
        let seconds = Double(duration.components.seconds)
        return Int(seconds * 1000 + Double(attos) / 1_000_000_000_000_000)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/ConfigurationCodeFormatter.swift
git commit -m "Sample: ConfigurationCodeFormatter — config -> Swift source

Pure value-in / string-out helper. Renders only the fields that differ
from EditorConfiguration() defaults; emits sections (Display/Layout/
Behavior/Performance) as direct property assignments matching the
'Direct updates (preferred)' pattern from CLAUDE.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: InspectorSidebar

EditorSidebarShell wrapper rendering the formatter's output + a Copy button.

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 1: Create `InspectorSidebar.swift`**

```swift
import AppKit
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right sidebar: live `EditorConfiguration` rendered as Swift source,
/// with a Copy button.
struct InspectorSidebar: View {
    let configuration: EditorConfiguration

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                ScrollView {
                    Text(rendered)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
            },
            footer: {
                HStack {
                    Spacer()
                    Button("Copy") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(rendered, forType: .string)
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        )
        .frame(width: 360)
    }

    private var rendered: String {
        ConfigurationCodeFormatter.render(configuration)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "Sample: InspectorSidebar — live config + Copy

EditorSidebarShell wrapper, sectionTitle 'Configuration'. Content slot
shows the formatter output in monospaced text with selection enabled;
footer slot has a Copy-to-pasteboard button.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Window assembly

Bring the chrome together: title bar + tab strip + body (settings | editor | inspector) + status bar. Remove the placeholder Text from CodeEditorSampleApp.

**Files:**
- Create: `Sources/CodeEditorSample/App/WindowBody.swift`
- Create: `Sources/CodeEditorSample/App/RootWindow.swift`
- Modify: `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`

- [ ] **Step 1: Create `WindowBody.swift`**

```swift
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Horizontal split: settings | editor | inspector.
struct WindowBody: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore
    @Binding var settingsVisible: Bool
    @Binding var inspectorVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if settingsVisible {
                SettingsSidebar(
                    theme: $theme,
                    configuration: $configuration,
                    documents: documents
                )
            }
            editorPane
            if inspectorVisible {
                InspectorSidebar(configuration: configuration)
            }
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        if let activeID = documents.activeTabID {
            CodeEditor(text: documents.textBinding(for: activeID))
                .codeLanguage(documents.activeLanguage ?? .plainText)
                .environment(\.codeEditorConfiguration, configuration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No tabs open")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Use ⌘⇧P → New Tab")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Create `RootWindow.swift`**

```swift
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Vertical stack: title bar + tab strip + body + status bar.
/// Owns sidebar visibility flags and the command-palette presentation
/// flag. Will receive ⌘⇧P binding in Task 14.
struct RootWindow: View {
    @State private var theme: Theme = ThemeCatalog.default
    @State private var configuration: EditorConfiguration = PresetCatalog.default.configuration
    @State private var documentStore = DocumentStore()
    @State private var settingsVisible: Bool = true
    @State private var inspectorVisible: Bool = true
    @State private var paletteVisible: Bool = false

    var body: some View {
        // Apple-documented pattern for projecting bindings into an
        // @Observable class held in @State: shadow with @Bindable
        // inside body so `$documents.tabs` / `$documents.activeTabID`
        // produce real Bindings rather than Binding<DocumentStore>.
        @Bindable var documents = documentStore
        VStack(spacing: 0) {
            EditorTitleBar(title: "CodeEditorSample")
            EditorTabStrip(
                tabs: $documents.tabs,
                activeTabID: $documents.activeTabID
            )
            WindowBody(
                theme: $theme,
                configuration: $configuration,
                documents: documentStore,
                settingsVisible: $settingsVisible,
                inspectorVisible: $inspectorVisible
            )
            EditorStatusBar()
        }
        .codeTheme(theme)
        .environment(\.codeEditorConfiguration, configuration)
    }
}
```

- [ ] **Step 3: Replace `CodeEditorSampleApp.swift` body with `RootWindow`**

```swift
import SwiftUI

@main
struct CodeEditorSampleApp: App {
    var body: some Scene {
        WindowGroup("CodeEditorSample") {
            RootWindow()
                .frame(minWidth: 980, minHeight: 640)
                .frame(width: 1380, height: 880)
        }
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Smoke-run the full window**

Run: `swift run CodeEditorSample`
Expected: a 1380×880 window opens with title bar, empty tab strip showing one `Untitled-1.swift` tab, three-pane body (settings sidebar | editor | inspector sidebar), and a status bar at the bottom. Theme reads as `LCARS Dark`. Typing into the editor enables the dirty dot on the tab. Editing knobs in the settings sidebar updates the inspector's rendered Swift code.

- [ ] **Step 6: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/App/
git commit -m "Sample: assemble RootWindow + WindowBody, retire boot placeholder

Full chrome wiring: EditorTitleBar (decorative) on top,
EditorTabStrip below, three-pane body (SettingsSidebar | CodeEditor |
InspectorSidebar), EditorStatusBar at the bottom. RootWindow owns
theme, configuration, DocumentStore, sidebar-visibility, and palette
visibility @State. CodeEditorSampleApp now hosts RootWindow at
1380x880 (980x640 min).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Command palette catalog + ⌘⇧P binding

Build the live command catalog and overlay the palette on top of the window when `paletteVisible` is true.

**Files:**
- Create: `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`
- Modify: `Sources/CodeEditorSample/App/RootWindow.swift`

- [ ] **Step 1: Create `CommandPaletteCatalog.swift`**

```swift
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI

/// Live builder for the command-palette item set. Returns a parallel
/// dispatch closure so the host can run the action when the user
/// confirms a row.
enum CommandPaletteCatalog {
    @MainActor
    static func build(
        theme: Binding<Theme>,
        configuration: Binding<EditorConfiguration>,
        documents: DocumentStore,
        settingsVisible: Binding<Bool>,
        inspectorVisible: Binding<Bool>
    ) -> (items: [CommandPaletteItem], dispatch: (CommandPaletteItem) -> Void) {
        var items: [CommandPaletteItem] = []
        var actions: [CommandPaletteItem.ID: () -> Void] = [:]

        for chosen in ThemeCatalog.all {
            let item = CommandPaletteItem(title: "Theme: \(chosen.name)", kind: .setting)
            actions[item.id] = { theme.wrappedValue = chosen }
            items.append(item)
        }

        for language in LanguageCatalog.all {
            let item = CommandPaletteItem(title: "Language: \(language.name)", kind: .setting)
            actions[item.id] = {
                guard let id = documents.activeTabID else { return }
                documents.setLanguage(language, of: id)
            }
            items.append(item)
        }

        for preset in PresetCatalog.all {
            let item = CommandPaletteItem(title: "Preset: \(preset.name)", kind: .setting)
            actions[item.id] = { configuration.wrappedValue = preset.configuration }
            items.append(item)
        }

        let newTab = CommandPaletteItem(title: "New Tab", kind: .action, shortcut: "⌘T")
        actions[newTab.id] = { documents.newTab() }
        items.append(newTab)

        let closeTab = CommandPaletteItem(title: "Close Tab", kind: .action, shortcut: "⌘W")
        actions[closeTab.id] = {
            if let id = documents.activeTabID { documents.close(id) }
        }
        items.append(closeTab)

        let closeAll = CommandPaletteItem(title: "Close All Tabs", kind: .action)
        actions[closeAll.id] = { documents.closeAll() }
        items.append(closeAll)

        let toggleSettings = CommandPaletteItem(title: "Toggle Settings Sidebar", kind: .action)
        actions[toggleSettings.id] = { settingsVisible.wrappedValue.toggle() }
        items.append(toggleSettings)

        let toggleInspector = CommandPaletteItem(title: "Toggle Inspector", kind: .action)
        actions[toggleInspector.id] = { inspectorVisible.wrappedValue.toggle() }
        items.append(toggleInspector)

        return (items, { picked in actions[picked.id]?() })
    }
}
```

- [ ] **Step 2: Wire ⌘⇧P + palette overlay into `RootWindow`**

Replace the `body` of `RootWindow` with:

```swift
var body: some View {
    @Bindable var documents = documentStore
    let (items, dispatch) = CommandPaletteCatalog.build(
        theme: $theme,
        configuration: $configuration,
        documents: documentStore,
        settingsVisible: $settingsVisible,
        inspectorVisible: $inspectorVisible
    )
    return ZStack {
        VStack(spacing: 0) {
            EditorTitleBar(title: "CodeEditorSample")
            EditorTabStrip(
                tabs: $documents.tabs,
                activeTabID: $documents.activeTabID
            )
            WindowBody(
                theme: $theme,
                configuration: $configuration,
                documents: documentStore,
                settingsVisible: $settingsVisible,
                inspectorVisible: $inspectorVisible
            )
            EditorStatusBar()
        }

        if paletteVisible {
            EditorCommandPalette(
                isPresented: $paletteVisible,
                items: items,
                onSelect: dispatch
            )
            .frame(maxWidth: 480)
            .padding(.top, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    .codeTheme(theme)
    .environment(\.codeEditorConfiguration, configuration)
    .background(togglePaletteShortcut)
}

private var togglePaletteShortcut: some View {
    Button("Toggle Palette") { paletteVisible.toggle() }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .opacity(0)
        .frame(width: 0, height: 0)
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Smoke-run the palette**

Run: `swift run CodeEditorSample`
Expected: pressing `⌘⇧P` opens the command palette over the chrome. Typing `theme:` filters to the 20 theme commands; selecting one updates the chrome instantly. `New Tab` adds an `Untitled-N.swift`. `Close Tab` removes the active. `Toggle Settings Sidebar` and `Toggle Inspector` hide/show the side panels.

- [ ] **Step 5: SwiftLint**

Run: `swiftlint`
Expected: `Done linting! Found 0 violations…`

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift Sources/CodeEditorSample/App/RootWindow.swift
git commit -m "Sample: command palette catalog + ⌘⇧P binding

CommandPaletteCatalog builds [CommandPaletteItem] + dispatch closure
from the live state — every theme, language, preset, plus New Tab,
Close Tab, Close All Tabs, Toggle Settings Sidebar, Toggle Inspector.
RootWindow overlays the EditorCommandPalette inside a ZStack and binds
⌘⇧P via an offscreen Button.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Final verification + CHANGELOG entry

Cross every gate in the spec; write the sub-project 5 sign-off.

**Files:**
- Modify: `CHANGELOG.md` (add new section after the last `### …` heading under `## Unreleased`)

- [ ] **Step 1: Run the full quality pipeline**

Run: `swift build && swiftlint && swift test --parallel`
Expected: `Build complete!`, `Done linting! Found 0 violations…`, and `187 tests in 48 suites passed` (or higher — 187 is the post-Task 12 baseline from sub-project 4's sign-off).

- [ ] **Step 2: Manual demo verification**

Run: `swift run CodeEditorSample`. Walk the checklist:

- [ ] Window opens at ~1380×880 with title bar, tab strip, three-pane body, status bar.
- [ ] Default theme reads as `LCARS Dark`; status-bar GPU pill shows.
- [ ] Default tab `Untitled-1.swift` is active.
- [ ] Typing in the editor flips the tab's dirty dot on.
- [ ] Theme picker in settings sidebar switches the chrome to a different `zed-trek` variant; inspector content stays unchanged.
- [ ] Language picker reflects the active tab's language; selecting another language updates the tab's `language` field.
- [ ] Preset picker (`.minimal`, `.markdown`, etc.) replaces the live config; every knob row reflects the new value; inspector re-renders.
- [ ] Display section: every knob (font size, line numbers, etc.) edits visibly.
- [ ] Layout section: every knob edits visibly.
- [ ] Behavior section: every knob edits visibly; `completionTriggerCharacters` field round-trips on Return.
- [ ] Performance section: every knob edits visibly.
- [ ] Inspector "Copy" button copies rendered Swift to pasteboard (paste somewhere to verify).
- [ ] `⌘⇧P` opens the palette; arrow keys move highlight; Return dispatches; `Esc` closes.
- [ ] Palette: `Theme: …`, `Language: …`, `Preset: …`, `New Tab`, `Close Tab`, `Close All Tabs`, `Toggle Settings Sidebar`, `Toggle Inspector` all dispatch correctly.
- [ ] Quitting: window closes cleanly, `swift run` exits 0.

- [ ] **Step 3: Add CHANGELOG entry**

Open `CHANGELOG.md`. Find the `## Unreleased` section. Insert this new section above the existing `### CodeEditorUI chrome primitives (sub-project 4)` heading:

```markdown
### CodeEditorSample executable (sub-project 5 — design-system migration capstone)

`CodeEditorSample` is the integration capstone for the design-system
migration. macOS `executableTarget` that boots into a single 1380×880
window exercising every public surface added in sub-projects 1–4.
Run with `swift run CodeEditorSample`.

Owns no filesystem and no documents-on-disk. Boots to a single empty
`Untitled-1.swift` tab; the user types their own code. Zero new
package dependencies — links the existing three library products plus
SwiftUI / AppKit.

#### Added

- `Package.swift` — `CodeEditorSample` `executableTarget` and product.
- `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift` — `@main`
  SwiftUI App; WindowGroup; window resizability content-size.
- `Sources/CodeEditorSample/App/RootWindow.swift` — vertical stack
  (`EditorTitleBar` → `EditorTabStrip` → body → `EditorStatusBar`),
  owns theme / configuration / `DocumentStore` / sidebar-visibility /
  palette-visibility `@State`, binds ⌘⇧P via offscreen Button +
  `.keyboardShortcut`.
- `Sources/CodeEditorSample/App/WindowBody.swift` — horizontal split
  (settings sidebar | `CodeEditor` | inspector sidebar) with an
  empty-state pane when no tabs are open.
- `Sources/CodeEditorSample/Documents/DocumentStore.swift` —
  `@MainActor @Observable` class; owns `[TabModel]`, per-tab text
  dictionary keyed by `TabModel.id`, `activeTabID`, and an
  `Untitled-N` counter. `newTab` / `close(_:)` / `closeAll` /
  `setActive(_:)` / `textBinding(for:)` / `setLanguage(_:of:)`.
- `Sources/CodeEditorSample/Switchers/{Theme,Language,Preset}Catalog.swift` —
  static catalogs for the picker rows; theme list pulls the 20
  `zed-trek` variants from `ThemeFamily.bundled("zed-trek")`; preset
  list wraps the six demo presets in `ConfigurationPreset` for binding
  by id.
- `Sources/CodeEditorSample/Switchers/SwitcherSection.swift` — three
  `Picker` rows (Theme / Language / Preset) at the top of the settings
  sidebar.
- `Sources/CodeEditorSample/KnobPanels/KnobRow.swift` — reusable row
  primitives: `ToggleRow`, `StepperRow`, `SliderRow`,
  `CGFloatSliderRow`, `PickerRow<T>`, `ColorRow`, `CharSetRow`,
  `DurationRow`.
- `Sources/CodeEditorSample/KnobPanels/{Display,Layout,Behavior,Performance}KnobsSection.swift` —
  four collapsible `DisclosureGroup`s wiring every user-facing
  `EditorConfiguration` knob (52 in total). DI hooks and iOS-only
  knobs deliberately omitted.
- `Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift` — left
  sidebar shell wrapping switchers + four knob sections inside an
  `EditorSidebarShell`.
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` — right
  sidebar shell rendering the live config as Swift; `NSPasteboard`
  copy button in the footer.
- `Sources/CodeEditorSample/Sidebars/ConfigurationCodeFormatter.swift` —
  pure value-in / string-out helper. Emits direct property
  assignments for every field that differs from the
  `EditorConfiguration()` default; groups by Display / Layout /
  Behavior / Performance.
- `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` —
  live builder for `[CommandPaletteItem]` + dispatch closure: every
  theme, language, preset, plus `New Tab`, `Close Tab`,
  `Close All Tabs`, `Toggle Settings Sidebar`, `Toggle Inspector`.

#### Tests

None — sub-project 5 is a demo. Every surface it exercises has unit
or snapshot coverage in `CodeEditorPluginTests`, `CodeEditorUITests`,
and `CodeEditorDesignTokensTests`. Verification gate is manual: `swift
build` + `swiftlint` clean, existing 187 tests still green,
`swift run CodeEditorSample` walks the acceptance checklist in the
spec's *Testing* section.

#### Scope deviations from the umbrella sketch

- **Dropped:** file-tree, `WorkspaceModel`, FSEvents/DispatchSource
  watching, virtualized rows, expand/collapse, search.
- **Dropped:** bundled sample-source files (Swift / TypeScript /
  Python / Rust / JSON exemplars).
- **Dropped:** breadcrumb (`EditorBreadcrumbView`) — no workspace
  path to show in an in-memory demo.

The spec records the rationale for each cut and the full design.

#### Sub-project 5 acceptance checklist

- [x] `Package.swift` exposes `CodeEditorSample` as an
      `executableTarget` and product; depends on the three library
      products only.
- [x] `swift run CodeEditorSample` boots into a 1380×880 window with
      title bar, tab strip, settings sidebar, editor, inspector
      sidebar, status bar.
- [x] All 20 `zed-trek` themes are pickable from the settings sidebar
      and the command palette.
- [x] All 25 concrete `Language` cases plus plain text are pickable.
- [x] All six demo presets snap-replace the live `EditorConfiguration`.
- [x] All 52 `EditorConfiguration` knobs are interactively editable;
      inspector mirrors every change.
- [x] `⌘⇧P` opens the command palette; every command dispatches
      correctly.
- [x] `swift build` clean, `swiftlint` zero violations,
      `swift test --parallel` 187/187 still green.
```

- [ ] **Step 4: Commit the CHANGELOG**

```bash
git add CHANGELOG.md
git commit -m "Sample: CHANGELOG entry for sub-project 5 sign-off

Captures the executable surface (App / RootWindow / WindowBody /
DocumentStore / catalogs / knob sections / sidebars / formatter /
command palette catalog), explicit scope deviations from the umbrella
sketch (file tree, bundled samples, breadcrumb dropped), and the
acceptance checklist confirming the verification gate cleared.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Push**

```bash
git push origin main
```

Expected: `bf806fb..<sha>  main -> main`

---

## Self-Review Notes

**Spec coverage:** Every section of the spec maps to a task —
`Package.swift` add (Task 1), `DocumentStore` (Task 2), three catalogs
(Task 3), switcher section (Task 4), six knob primitives (Task 5),
four knob sections (Tasks 6–9), settings sidebar shell (Task 10),
formatter (Task 11), inspector shell (Task 12), window assembly + min
size (Task 13), command palette + `⌘⇧P` (Task 14), verification +
CHANGELOG (Task 15). All four open questions from the spec are
resolved inline at implementation time:

1. **Inspector code-formatting fidelity:** Task 11's
   `ConfigurationCodeFormatter` uses `String(format: "%.2f", …)` for
   non-integer CGFloats and bare `Int(…)` for whole numbers — clean
   for the demo without `.formatted()`'s locale dependence.
2. **`renderingUpdateStrategy` cases:** Task 9 lists the three
   confirmed cases (`.adaptive`, `.immediate`, `.batched`) that exist
   in the live enum.
3. **Theme list grouping:** Task 4 ships a flat `Picker.menu` list —
   simpler than implementing grouping by family color, matches the
   common macOS Picker idiom.
4. **Empty-config-default suppression in inspector:** Task 11 keeps
   the suppression and adds a "(every knob matches its default)"
   fallback line so the user never sees an empty inspector.
