import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    // Dark theme provides better contrast
    // and reduces eye strain in low light
    
    async function fetchUserData(userId: string) {
        try {
            const response = await fetch(`/api/users/${userId}`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const data = await response.json();
            console.log('User data:', data);
            return data;
        } catch (error) {
            console.error('Failed to fetch user:', error);
            throw error;
        }
    }
    
    // Usage
    fetchUserData('123')
        .then(user => console.log(user.name))
        .catch(err => console.error(err));
    """
    
    @State private var config = EditorConfiguration()
    @State private var isDarkMode = true
    
    var body: some View {
        VStack {
            Text("Theme Customization")
                .font(.headline)
                .padding()
            
            Toggle("Dark Mode", isOn: $isDarkMode)
                .padding(.horizontal)
                .onChange(of: isDarkMode) { newValue in
                    // Switch between themes
                    config.display.theme = newValue ? .oneDark : .xcode
                }
            
            CodeEditor(text: $code)
                .codeLanguage(.typescript)
                .environment(\.codeEditorConfiguration, config)
                .frame(minHeight: 400)
                .padding()
                .background(isDarkMode ? Color.black : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            // Start with dark theme
            config.display.theme = .oneDark
        }
    }
}
