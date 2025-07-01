# Mac Catalyst Build Notes

## Known Issues with Xcode Beta

When building for Mac Catalyst with Xcode beta, you may see the following warnings:

1. **Directory not found for Metal toolchain**
   - This is a known issue with Xcode beta and can be safely ignored
   - The Metal toolchain paths are not yet properly configured in beta releases

2. **Missing SubFrameworks path**
   - The path `/System/iOSSupport/System/Library/SubFrameworks` doesn't exist in macOS 26.0 SDK beta
   - This warning doesn't affect functionality

3. **Module import issues**
   - Ensure you're opening the workspace file, not the project file directly
   - Clean build folder: `cmd+shift+K`
   - Delete derived data if needed

## Workarounds

### Option 1: Use Release Xcode
If possible, use the stable release version of Xcode for Mac Catalyst builds.

### Option 2: Build from Command Line
```bash
# Build for Mac Catalyst from command line
xcodebuild -workspace CodeEditorSample.xcworkspace \
           -scheme CodeEditorSample \
           -destination 'platform=macOS,variant=Mac Catalyst' \
           build
```

### Option 3: Suppress Warnings
Add the following to your scheme's build settings:
- Other Linker Flags: `-Xlinker -w`
- Other Swift Flags: `-suppress-warnings`

### Option 4: Use the xcconfig file
1. In Xcode, select your project
2. In Build Settings, set "Based on Configuration File" to `MacCatalyst.xcconfig`

## Building with Swift Package Manager

For command-line builds without warnings:
```bash
swift build --arch arm64 --arch x86_64
```

## Notes

- These warnings are cosmetic and don't affect the app's functionality
- The app should run correctly despite the warnings
- These issues will likely be resolved in future Xcode beta releases