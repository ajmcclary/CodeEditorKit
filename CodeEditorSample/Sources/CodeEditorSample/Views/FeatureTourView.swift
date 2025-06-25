import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - FeatureTourView

struct FeatureTourView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    let tourSteps = [
        TourStep(
            title: "Welcome to CodeEditor Sample",
            description: "This app demonstrates all the features of the CodeEditorPlugin. Let's take a quick tour!",
            feature: nil,
            icon: "hand.wave"
        ),
        TourStep(
            title: "Syntax Highlighting",
            description: [
                "The editor supports syntax highlighting for multiple languages including Swift,",
                "JavaScript, Python, and more. Try switching between different sample code languages."
            ].joined(separator: " "),
            feature: .syntaxHighlighting,
            icon: "paintbrush"
        ),
        TourStep(
            title: "Line Numbers",
            description: [
                "Toggle line numbers on/off to suit your preference. Line numbers help with",
                "navigation and debugging."
            ].joined(separator: " "),
            feature: .lineNumbers,
            icon: "number"
        ),
        TourStep(
            title: "Themes",
            description: [
                "Choose from multiple color themes including Xcode, VS Dark, GitHub, and more.",
                "Each theme is carefully designed for optimal readability."
            ].joined(separator: " "),
            feature: .themes,
            icon: "paintpalette"
        ),
        TourStep(
            title: "Configuration Presets",
            description: [
                "Quick presets for different use cases: Full Featured, Minimal, Read Only,",
                "Markdown, and Presentation modes."
            ].joined(separator: " "),
            feature: .presets,
            icon: "slider.horizontal.3"
        ),
        TourStep(
            title: "Line Highlighting",
            description: "The current line can be highlighted to help you keep track of where you are in the code.",
            feature: .lineHighlighting,
            icon: "text.line.first.and.arrowtriangle.forward"
        ),
        TourStep(
            title: "Customization",
            description: [
                "Fine-tune every aspect: font size, line spacing, tab width,",
                "invisible characters, and more."
            ].joined(separator: " "),
            feature: .customization,
            icon: "gearshape.2"
        ),
        TourStep(
            title: "Performance",
            description: [
                "The editor is optimized for performance with hardware acceleration and",
                "efficient syntax highlighting."
            ].joined(separator: " "),
            feature: .performance,
            icon: "speedometer"
        ),
        TourStep(
            title: "Start Exploring!",
            description: "That's all for the tour! Feel free to explore all the features and " +
                "configurations. Happy coding!",
            feature: nil,
            icon: "star"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feature Tour")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Skip Tour") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            #if canImport(AppKit)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif

            Divider()

            // Content
            VStack(spacing: 24) {
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0 ..< tourSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.top)

                // Current step content
                VStack(spacing: 16) {
                    Image(systemName: tourSteps[currentStep].icon)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.hierarchical)

                    Text(tourSteps[currentStep].title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(tourSteps[currentStep].description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 400)
                }
                .padding(.horizontal)

                Spacer()

                // Navigation buttons
                HStack {
                    Button("Previous") {
                        withAnimation(.spring()) {
                            currentStep = max(0, currentStep - 1)
                        }
                    }
                    .disabled(currentStep == 0)

                    Spacer()

                    if currentStep < tourSteps.count - 1 {
                        Button("Next") {
                            withAnimation(.spring()) {
                                currentStep += 1
                            }
                            highlightFeature()
                        }
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Finish Tour") {
                            isPresented = false
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding()
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        #if canImport(AppKit)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .onAppear {
            highlightFeature()
        }
    }

    private func highlightFeature() {
        // Post notification to highlight the current feature
        if let feature = tourSteps[currentStep].feature {
            NotificationCenter.default.post(
                name: .highlightFeature,
                object: nil,
                userInfo: ["feature": feature]
            )
        }
    }
}

// MARK: - TourStep

struct TourStep {
    let title: String
    let description: String
    let feature: TourFeature?
    let icon: String
}

// MARK: - TourFeature

enum TourFeature {
    case syntaxHighlighting
    case lineNumbers
    case themes
    case presets
    case lineHighlighting
    case customization
    case performance
}

extension Notification.Name {
    static let highlightFeature = Notification.Name("highlightFeature")
}
