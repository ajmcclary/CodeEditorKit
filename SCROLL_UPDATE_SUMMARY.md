# Auto Scroll to Cursor Configuration Update

## Summary
Updated all navigation methods across the codebase to respect the new `autoScrollToCursor` configuration option in `EditorConfiguration.behavior`. This ensures that scrolling behavior can be controlled by the user across all platforms (AppKit, UIKit, Mac Catalyst).

## Files Updated

### 1. **CodeEditorView+CodeEditorAPI.swift**
- `scrollToVisible(_:)` method (line 167) - Already properly checks `configuration.behavior.autoScrollToCursor`
- `scrollToLine(_:)` method (line 176) - Already properly checks `configuration.behavior.autoScrollToCursor`

### 2. **CodeEditorContainerView.swift**
- `navigateToLine(_:)` method - Already properly checks `configuration.behavior.autoScrollToCursor` at:
  - Line 540 (macOS, non-zero line)
  - Line 548 (macOS, first line)
  - Line 568 (iOS, non-zero line)
  - Line 578 (iOS, first line)

### 3. **SymbolNavigator.swift** ✅ UPDATED
- `navigate(to:)` method (line 195) - Now checks `textView.configuration.behavior.autoScrollToCursor` before calling `scrollRangeToVisible`

### 4. **SearchReplaceEngine.swift** ✅ UPDATED
- `scrollToResult(_:)` method (line 338) - Now checks `textView.configuration.behavior.autoScrollToCursor` before calling `scrollRangeToVisible`

### 5. **ContainerViewHelper.swift** ✅ UPDATED
- `navigateToLine(_:in:)` method - Now checks `textView.configuration.behavior.autoScrollToCursor` before calling:
  - `scrollRangeToVisible` on macOS (line 34)
  - `scrollRectToVisible` on iOS (line 44)

## Behavior
When `configuration.behavior.autoScrollToCursor` is:
- `true` (default): All navigation operations will scroll the view to make the target location visible
- `false`: Navigation operations will update the cursor position but will NOT scroll the view

This gives users full control over scrolling behavior, which is particularly useful for:
- Performance optimization in large files
- Maintaining scroll position during programmatic edits
- Custom scroll management in specialized editors
- Accessibility features that require stable viewport positioning