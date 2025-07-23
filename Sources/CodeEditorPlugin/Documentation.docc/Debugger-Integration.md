# Debugger Integration

@Metadata {
    @PageColor(purple)
}

Learn how to integrate debugging capabilities into your code editor with breakpoints, variable inspection, and debug adapters.

## Overview

CodeEditorPlugin provides a comprehensive debugger integration system that supports multiple debug adapters including LLDB, Python debugger, and Node.js debugger. The system allows you to add debugging capabilities to your editor with features like breakpoints, stepping, variable inspection, and call stack visualization.

## Architecture

The debugger integration consists of several key components:

- **DebuggerManager**: Central coordinator for debugging sessions
- **Debug Adapters**: Protocol implementations for different debuggers (LLDB, Python, Node.js)
- **Breakpoint Management**: Visual and functional breakpoint handling
- **Debug UI**: Integrated UI components for debugging controls

## Basic Setup

### Enabling Debugger Support

```swift
import CodeEditorPlugin

// Create editor with debugger support
var config = EditorConfiguration()
config.features.enableDebugger = true

let editor = CodeEditorView()
config.apply(to: editor)

// Access the debugger manager
let debuggerManager = editor.debuggerManager
```

### Setting Breakpoints

```swift
// Add a breakpoint at line 10
debuggerManager.addBreakpoint(at: 10)

// Add a conditional breakpoint
debuggerManager.addBreakpoint(at: 15, condition: "count > 5")

// Remove a breakpoint
debuggerManager.removeBreakpoint(at: 10)

// Toggle breakpoint
debuggerManager.toggleBreakpoint(at: 20)
```

## Debug Adapters

### LLDB Adapter

For debugging Swift, C, C++, and Objective-C:

```swift
let lldbAdapter = LLDBDebugAdapter()

// Configure LLDB
lldbAdapter.executable = "/path/to/your/binary"
lldbAdapter.arguments = ["--arg1", "value1"]
lldbAdapter.environment = ["DEBUG": "1"]

// Start debugging
try await debuggerManager.startDebugging(with: lldbAdapter)
```

### Python Debugger

For debugging Python scripts:

```swift
let pythonAdapter = PythonDebugAdapter()

// Configure Python debugger
pythonAdapter.scriptPath = "/path/to/script.py"
pythonAdapter.pythonPath = "/usr/bin/python3"
pythonAdapter.args = ["--verbose"]

// Start debugging
try await debuggerManager.startDebugging(with: pythonAdapter)
```

### Node.js Debugger

For debugging JavaScript/TypeScript:

```swift
let nodeAdapter = NodeDebugAdapter()

// Configure Node debugger
nodeAdapter.program = "/path/to/app.js"
nodeAdapter.port = 9229
nodeAdapter.sourceMaps = true

// Start debugging
try await debuggerManager.startDebugging(with: nodeAdapter)
```

## Debug Controls

### Basic Operations

```swift
// Continue execution
await debuggerManager.continue()

// Step over
await debuggerManager.stepOver()

// Step into
await debuggerManager.stepInto()

// Step out
await debuggerManager.stepOut()

// Pause execution
await debuggerManager.pause()

// Stop debugging
await debuggerManager.stop()
```

### Variable Inspection

```swift
// Get variables in current scope
let variables = await debuggerManager.getVariables()

// Inspect specific variable
let value = await debuggerManager.evaluateExpression("myVariable")

// Watch expression
debuggerManager.addWatchExpression("array.count")
```

### Call Stack

```swift
// Get current call stack
let callStack = await debuggerManager.getCallStack()

// Select stack frame
await debuggerManager.selectFrame(at: 2)
```

## UI Integration

### Breakpoint Gutter

The editor automatically shows breakpoint indicators in the gutter:

```swift
// Customize breakpoint appearance
config.debugger.breakpointColor = .systemRed
config.debugger.conditionalBreakpointColor = .systemOrange
config.debugger.disabledBreakpointColor = .systemGray
```

### Debug Console

Integrate a debug console for output:

```swift
// Set up debug console
let console = DebugConsoleView()
debuggerManager.consoleOutput = { message in
    console.append(message)
}

// Clear console
console.clear()
```

### Variable Inspector

Display variables in a structured view:

```swift
struct VariableInspectorView: View {
    @ObservedObject var debuggerManager: DebuggerManager
    
    var body: some View {
        List(debuggerManager.variables) { variable in
            HStack {
                Text(variable.name)
                Spacer()
                Text(variable.value)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

## Advanced Features

### Remote Debugging

Support for debugging remote applications:

```swift
let remoteAdapter = RemoteDebugAdapter()
remoteAdapter.host = "192.168.1.100"
remoteAdapter.port = 5678
remoteAdapter.protocol = .dap // Debug Adapter Protocol

try await debuggerManager.connectRemote(adapter: remoteAdapter)
```

### Custom Debug Adapters

Create your own debug adapter:

```swift
class CustomDebugAdapter: DebugAdapter {
    func start() async throws {
        // Initialize your debugger
    }
    
    func setBreakpoint(_ breakpoint: Breakpoint) async throws {
        // Set breakpoint in your debugger
    }
    
    func continue() async throws {
        // Continue execution
    }
    
    // Implement other required methods...
}
```

### Debug Configuration

Save and load debug configurations:

```swift
// Save configuration
let config = DebugConfiguration(
    name: "My App Debug",
    adapter: .lldb,
    executable: "/path/to/app",
    arguments: ["--debug"],
    environment: ["DEBUG": "1"]
)

try config.save(to: configURL)

// Load configuration
let loadedConfig = try DebugConfiguration.load(from: configURL)
try await debuggerManager.startDebugging(with: loadedConfig)
```

## Best Practices

1. **Performance**: Disable debugger features when not needed to improve performance
2. **Error Handling**: Always handle debugger errors gracefully
3. **UI Feedback**: Provide clear visual feedback for debug states
4. **Breakpoint Persistence**: Save breakpoints between sessions
5. **Memory Management**: Clean up debug sessions properly

## Platform Considerations

- **macOS**: Full debugger support with all adapters
- **iOS**: Limited to remote debugging due to sandboxing
- **Mac Catalyst**: Supports local debugging with some restrictions

## See Also

- <doc:LSP-Integration>
- <doc:Architecture-Overview>
- <doc:Performance-Monitoring>