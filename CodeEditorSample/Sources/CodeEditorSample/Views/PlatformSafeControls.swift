import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Platform Safe Controls

/// A completely safe toggle that uses native platform controls to avoid SwiftUI concurrency issues
struct PlatformSafeToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }
    
    var body: some View {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        MacOSToggleView(title: title, isOn: $isOn)
        #else
        IOSToggleView(title: title, isOn: $isOn)
        #endif
    }
}

// MARK: - macOS Implementation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
struct MacOSToggleView: NSViewRepresentable {
    let title: String
    @Binding var isOn: Bool
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        // Create label
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Create switch (using NSButton with switch style)
        let switchButton = NSButton()
        switchButton.setButtonType(.switch)
        switchButton.title = ""
        switchButton.state = isOn ? .on : .off
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up action
        switchButton.target = context.coordinator
        switchButton.action = #selector(Coordinator.toggleChanged(_:))
        
        // Add to container
        containerView.addSubview(label)
        containerView.addSubview(switchButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            switchButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            switchButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            switchButton.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            
            containerView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Store references in coordinator
        context.coordinator.switchButton = switchButton
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.switchButton?.state = isOn ? .on : .off
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var parent: MacOSToggleView
        weak var switchButton: NSButton?
        
        init(_ parent: MacOSToggleView) {
            self.parent = parent
        }
        
        @objc func toggleChanged(_ sender: NSButton) {
            // Update binding directly on main thread - no async needed
            parent.isOn = sender.state == .on
        }
    }
}
#endif

// MARK: - iOS Implementation

#if canImport(UIKit)
struct IOSToggleView: UIViewRepresentable {
    let title: String
    @Binding var isOn: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        // Create label
        let label = UILabel()
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Create switch
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up action
        toggle.addTarget(context.coordinator, action: #selector(Coordinator.toggleChanged(_:)), for: .valueChanged)
        
        // Add to container
        containerView.addSubview(label)
        containerView.addSubview(toggle)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            toggle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            
            containerView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Store reference in coordinator
        context.coordinator.toggle = toggle
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.toggle?.isOn = isOn
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var parent: IOSToggleView
        weak var toggle: UISwitch?
        
        init(_ parent: IOSToggleView) {
            self.parent = parent
        }
        
        @objc func toggleChanged(_ sender: UISwitch) {
            // Update binding directly on main thread
            parent.isOn = sender.isOn
        }
    }
}
#endif

// MARK: - Platform Safe Button

/// A completely safe button that uses native platform controls
struct PlatformSafeButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        MacOSButtonView(action: action, label: label)
        #else
        IOSButtonView(action: action, label: label)
        #endif
    }
}

// MARK: - macOS Button Implementation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
struct MacOSButtonView<Label: View>: NSViewRepresentable {
    let action: () -> Void
    let label: () -> Label
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonPressed)
        
        // Set up SwiftUI content
        let hostingView = NSHostingView(rootView: label())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4)
        ])
        
        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var parent: MacOSButtonView
        
        init(_ parent: MacOSButtonView) {
            self.parent = parent
        }
        
        @objc func buttonPressed() {
            // Execute action directly on main thread
            parent.action()
        }
    }
}
#endif

// MARK: - iOS Button Implementation

#if canImport(UIKit)
struct IOSButtonView<Label: View>: UIViewRepresentable {
    let action: () -> Void
    let label: () -> Label
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonPressed), for: .touchUpInside)
        
        // Set up SwiftUI content
        let hostingController = UIHostingController(rootView: label())
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        button.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
            hostingController.view.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            hostingController.view.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            hostingController.view.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4)
        ])
        
        return button
    }
    
    func updateUIView(_ uiView: UIButton, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var parent: IOSButtonView
        
        init(_ parent: IOSButtonView) {
            self.parent = parent
        }
        
        @objc func buttonPressed() {
            // Execute action directly on main thread
            parent.action()
        }
    }
}
#endif
