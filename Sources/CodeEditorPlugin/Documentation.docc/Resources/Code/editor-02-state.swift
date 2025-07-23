import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    // Create a state property to hold the code text
    @State private var code = """
function hello() {
    console.log("Hello, World!");
}

hello();
"""

    var body: some View {
        Text("Hello, World!")
    }
}
