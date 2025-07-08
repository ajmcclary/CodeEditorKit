# REVIEW 1

# Code Review

## API Design & Ergonomics

### 1. Unused initializer parameters in CodeEditor

CodeEditor provides convenience initializers that accept language and theme parameters, but these values are ignored – the view always reads them from the environment. This can confuse developers who expect those parameters to take effect.

```swift
210  public init(
211      text: Binding<String>,
212      language _: Language,
213      theme _: CodeEditorSwiftUITheme = .default,
214      debounceInterval: Duration = .milliseconds(100)
215  ) {
216      self._text = text
217      self.textDebounceInterval = debounceInterval
218  }
```

**Recommendation:** Store the passed language and theme in properties and set the corresponding environment values during initialization.

**Suggested task:** Honor `language` and `theme` parameters in CodeEditor initializers

### 2. Repeated Mac Catalyst color handling

Color assignment to UITextView for Mac Catalyst is duplicated in both setupContainer and updateContainer:

```swift
textStorage.beginEditing()
textStorage.addAttribute(.foregroundColor, value: effectiveTextColor, range: NSRange(location:0,length:textStorage.length))
textStorage.endEditing()
```

**Recommendation:** Extract this logic into a shared helper (e.g., applyTextColor(for:)) to simplify maintenance.

**Suggested task:** Deduplicate Mac Catalyst text color logic

### 3. Builder pattern could surface validation results

EditorConfigurationBuilder.build() silently auto‑fixes issues with ConfigurationValidator.autoFix(&finalConfig):

```swift
489  public func build() -> EditorConfiguration {
490      var finalConfig = configuration
491      let validator = ConfigurationValidator()
492      _ = validator.autoFix(&finalConfig)
493      return finalConfig
494  }
```

Developers may want to know if any fixes were applied or if configuration is invalid.

**Suggested task:** Expose validation feedback from configuration builder

## Architecture & Scalability

### 4. Repetitive platform checks

The pattern `#if canImport(AppKit) && !targetEnvironment(macCatalyst)` appears extensively (over 600 times). It hurts readability and maintainability.

**Recommendation:** Define a single build configuration flag or custom macro (CODEEDITOR_APPKIT) and use it across the codebase.

**Suggested task:** Introduce unified compile-time flag for AppKit checks

### 5. Cross‑platform coordinator responsibilities

CrossPlatformCoordinator currently mixes capability detection, platform adjustments, and input coordination. The type grows large and may be difficult to extend.

**Recommendation:** Extract platform‑specific adjustment logic into its own struct/service and keep the coordinator focused on high‑level orchestration.

**Suggested task:** Refactor CrossPlatformCoordinator for clearer responsibilities

## Code Quality & Best Practices

### 6. Async task cleanup in AsyncTextProcessor

AsyncTextProcessor launches Task instances for each queued operation but relies on taskCompleted to remove them from activeTasks. If a task never calls taskCompleted (e.g., due to early cancellation), the dictionary might leak.

**Recommendation:** Use defer within the processing task or Task's handle to guarantee removal.

**Suggested task:** Ensure active tasks are removed on cancellation

## Testing & Reliability

### 7. Expand cross‑platform integration tests

The test suite covers many core features but lacks Mac Catalyst–specific integration checks (e.g., color assignment, keyboard handling).

**Suggested task:** Add Mac Catalyst integration tests

### 8. Performance regression coverage

Large‑file handling and async processing rely on actors. There are no explicit performance tests verifying highlight times or memory usage when files exceed maxSyntaxHighlightingLength.

**Suggested task:** Introduce performance tests for large-file highlighting

## Documentation & Clarity

### 9. Clarify DocC pages referencing AI guides

The repository provides CLAUDE.md, GEMINI.md, and AGENTS.md. However, DocC articles don't mention them, which might confuse contributors.

**Suggested task:** Link AGENTS guides from DocC documentation

### 10. Remove TODO comment from README sample

The quick start snippet in README.md includes a "// TODO: Add more features" line which may be misleading.

```swift
print("Hello, CodeEditorPlugin!")
// TODO: Add more features
```

**Suggested task:** Clean sample code in README

## Testing

No tests were executed in this read-only review.

Codex couldn't run certain commands due to environment limitations. Consider configuring a setup script or internet access in your Codex environment to install dependencies.
