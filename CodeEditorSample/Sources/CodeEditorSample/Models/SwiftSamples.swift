import Foundation

// MARK: - Swift Samples

enum SwiftSamples {
    static let swiftSample = """
    import Foundation
    import SwiftUI

    // TODO: Add more documentation
    // FIXME: Handle edge cases in calculation
    // ERROR: Missing implementation for edge case

    /// A sample SwiftUI view demonstrating syntax highlighting
    struct ContentView: View {
        @State private var counter = 0
        @State private var showAlert = false

        var body: some View {
            VStack(spacing: 20) {
                Text("Hello, World!")
                    .font(.largeTitle)
                    .foregroundColor(.primary)

                Text("Counter: \\(counter)")
                    .font(.title2)

                HStack(spacing: 10) {
                    Button(action: increment) {
                        Label("Increment", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: decrement) {
                        Label("Decrement", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                }

                // Custom shape with animation
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 200, height: 50)
                    .overlay(
                        Text("\\(counter)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    )
                    .scaleEffect(showAlert ? 1.1 : 1.0)
                    .animation(.spring(), value: showAlert)
            }
            .padding()
            .alert("Counter Reset", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text("The counter has been reset to 0")
            }
        }

        private func increment() {
            withAnimation {
                counter += 1
            }
        }

        private func decrement() {
            withAnimation {
                counter -= 1
                if counter < 0 {
                    counter = 0
                    showAlert = true
                }
            }
        }
    }

    // Protocol demonstration
    protocol Calculable {
        associatedtype Value: Numeric
        func calculate(_ values: [Value]) -> Value
    }

    struct Calculator<T: Numeric>: Calculable {
        func calculate(_ values: [T]) -> T {
            values.reduce(0, +)
        }
    }

    // Async/await example
    class DataService {
        func fetchData() async throws -> [String] {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return ["Item 1", "Item 2", "Item 3"]
        }
    }
    """
    
    static let allSamples: [String: String] = [
        "SwiftUI Sample": swiftSample
    ]
}
