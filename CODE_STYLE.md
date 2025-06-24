# Code Style Guide

This project uses **SwiftLint** and **SwiftFormat** for consistent code formatting and style enforcement.

## Configuration Files

### Main Project
- **`.swiftlint.yml`**: Comprehensive SwiftLint configuration for production code
- **`.swiftformat`**: SwiftFormat configuration matching SwiftLint expectations

### Sample Project (`Example/CodeEditorSample/`)
- **`.swiftlint.yml`**: Relaxed configuration for educational/demo code
- **`.swiftformat`**: Basic formatting preserving code clarity for samples

## Usage

### Main Project
```bash
# Format and lint all code
swiftformat . && swiftlint --fix && swiftlint

# Quick format only
swiftformat .

# Quick lint only
swiftlint
```

### Sample Project
```bash
cd Example/CodeEditorSample/

# Format and lint sample code
swiftformat . && swiftlint --fix && swiftlint
```

## Key Features

### Main Project Configuration
- **Strict style enforcement** for production code quality
- **Swift 6 compatibility** with modern concurrency rules
- **TCA (The Composable Architecture) patterns** optimized rules
- **Comprehensive opt-in rules** for best practices
- **Custom rules** for project-specific requirements

### Sample Project Configuration
- **Relaxed rules** for educational clarity
- **Higher limits** for file/function lengths (demo code often shows complex examples)
- **Disabled docs requirements** (samples focus on functionality, not documentation)
- **Allows force unwrapping** and other patterns useful for demo clarity
- **TODO comments allowed** for educational notes

## Rule Highlights

### Enabled in Main Project
- `indentation_width` (temporarily disabled due to SwiftFormat edge cases)
- `number_separator` for large numbers
- `sorted_imports` for import organization
- `multiline_arguments` for complex function calls
- `vertical_parameter_alignment` for readability

### Relaxed in Sample Project
- Higher `cyclomatic_complexity` limits (20/30 vs 15/25)
- Higher `file_length` limits (1000/2000 vs default)
- Higher `function_body_length` limits (100/200 vs default)
- Disabled `force_unwrapping` rule
- Disabled `missing_docs` rule

## Integration Notes

### SwiftFormat + SwiftLint Compatibility
- SwiftFormat handles **formatting** (spacing, alignment, organization)
- SwiftLint handles **style rules** (naming, complexity, best practices)
- Both tools work together without conflicts
- Run `swiftformat . && swiftlint --fix` for automated cleanup

### CI/CD Integration
```bash
# Check formatting and style (fail on violations)
swiftformat --lint . && swiftlint --strict

# Auto-fix and commit (for development)
swiftformat . && swiftlint --fix
```

## Customization

### Adding New Rules
1. Update `.swiftlint.yml` in appropriate section (`opt_in_rules`, `disabled_rules`, or `custom_rules`)
2. Test with `swiftlint` to ensure no conflicts
3. Update sample project config if needed with relaxed versions

### SwiftFormat Changes
1. Update `.swiftformat` with new options
2. Test with `swiftformat . --lint` to verify
3. Ensure compatibility with SwiftLint by running both tools

## Troubleshooting

### Common Issues
- **Indentation conflicts**: Temporarily disabled `indentation_width` rule due to SwiftFormat edge cases with continuation lines
- **Import organization**: SwiftFormat handles this automatically with `--enable sortImports`
- **Brace spacing**: SwiftLint auto-fixes these violations

### Fixing Violations
1. Run `swiftformat .` first to handle formatting
2. Run `swiftlint --fix` to auto-correct simple violations
3. Manually fix remaining violations reported by `swiftlint`

## Project Structure Impact

### Directory-Specific Configs
- **Root level**: Production code with strict rules
- **Example/CodeEditorSample/**: Educational code with relaxed rules
- **Tests/**: Inherits main config but allows some test-specific patterns

This setup ensures production code quality while maintaining clarity and educational value in sample code.