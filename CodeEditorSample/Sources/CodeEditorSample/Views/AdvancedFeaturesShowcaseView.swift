// swiftlint:disable file_length
import SwiftUI
import CodeEditorPlugin

// MARK: - Advanced Features Showcase View

/// Demonstrates advanced features of the CodeEditor Plugin
@available(macOS 13.0, iOS 16.0, *)
struct AdvancedFeaturesShowcaseView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDemo: FeatureDemo = .multiCursor
    @State private var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @State private var showPerformanceMonitor = false
    @State private var animationState: AnimationState = .idle
    
    var body: some View {
        VStack(spacing: 0) {
            // Feature selection toolbar
            featureSelectionToolbar
            
            Divider()
            
            // Main demo area
            GeometryReader { geometry in
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                HSplitView {
                    // Demo code editor
                    demoEditorView
                        .frame(minWidth: geometry.size.width * 0.6)
                    
                    // Feature explanation panel
                    featureExplanationPanel
                        .frame(minWidth: geometry.size.width * 0.35)
                }
                #else
                HStack(spacing: 0) {
                    // Demo code editor
                    demoEditorView
                        .frame(width: geometry.size.width * 0.6)
                    
                    Divider()
                    
                    // Feature explanation panel
                    featureExplanationPanel
                        .frame(width: geometry.size.width * 0.4)
                }
                #endif
            }
            
            Divider()
            
            // Performance monitor
            if showPerformanceMonitor {
                performanceMonitorView
            }
        }
        .navigationTitle("Advanced Features Demo")
        .onAppear {
            loadDemoForCurrentFeature()
            startPerformanceMonitoring()
        }
        .onChange(of: selectedDemo) { _ in loadDemoForCurrentFeature() }
    }
    
    // MARK: - Feature Selection Toolbar
    
    @ViewBuilder
    private var featureSelectionToolbar: some View {
        HStack {
            // Feature picker
            Picker("Feature", selection: $selectedDemo) {
                ForEach(FeatureDemo.allCases, id: \.self) { demo in
                    HStack {
                        Image(systemName: demo.icon)
                        Text(demo.displayName)
                    }
                    .tag(demo)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
            
            Spacer()
            
            // Performance toggle - using PlatformSafeToggle to avoid MainActor crashes
            PlatformSafeToggle("Performance Monitor", isOn: $showPerformanceMonitor)
            
            // Animation controls - using PlatformSafeButton to avoid MainActor crashes
            HStack(spacing: 8) {
                PlatformSafeButton(action: startAnimation) {
                    Image(systemName: "play.fill")
                        .foregroundColor(animationState == .running ? .secondary : .accentColor)
                        .padding(8)
                        .background(Color.accentColor.opacity(animationState == .running ? 0.1 : 0.2))
                        .cornerRadius(8)
                }
                .disabled(animationState == .running)
                
                PlatformSafeButton(action: stopAnimation) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(animationState == .idle ? .secondary : .accentColor)
                        .padding(8)
                        .background(Color.accentColor.opacity(animationState == .idle ? 0.1 : 0.2))
                        .cornerRadius(8)
                }
                .disabled(animationState == .idle)
                
                PlatformSafeButton(action: resetDemo) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color(PlatformColors.controlBackground))
    }
    
    // MARK: - Demo Editor View
    
    @ViewBuilder
    private var demoEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Demo title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDemo.displayName)
                    .font(.headline)
                Text(selectedDemo.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Enhanced editor with demo-specific configuration
            SampleCodeEditorView(
                configuration: demoConfiguration,
                text: $appState.code,
                language: selectedDemo.preferredLanguage
            )
            .environmentObject(appState)
            .overlay(
                // Feature highlight overlays
                featureHighlightOverlay,
                alignment: .topTrailing
            )
        }
    }
    
    // MARK: - Feature Explanation Panel
    
    @ViewBuilder
    private var featureExplanationPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature overview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: selectedDemo.icon)
                            .foregroundColor(selectedDemo.accentColor)
                        Text("Feature Overview")
                            .font(.headline)
                    }
                    
                    Text(selectedDemo.explanation)
                        .font(.body)
                }
                
                Divider()
                
                // Key capabilities
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Capabilities")
                        .font(.headline)
                    
                    ForEach(selectedDemo.capabilities, id: \.self) { capability in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(capability)
                                .font(.body)
                            Spacer()
                        }
                    }
                }
                
                Divider()
                
                // Configuration settings
                configurationSection
                
                Divider()
                
                // Performance insights
                performanceInsightsSection
                
                Spacer()
            }
            .padding()
        }
        .background(Color(PlatformColors.controlBackground))
    }
    
    // MARK: - Configuration Section
    
    @ViewBuilder
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                configurationToggle(
                    "Syntax Highlighting",
                    binding: $appState.currentConfiguration.display.enableSyntaxHighlighting,
                    icon: "paintbrush.fill"
                )
                
                configurationToggle(
                    "Code Completion",
                    binding: $appState.currentConfiguration.behavior.enableCodeCompletion,
                    icon: "text.insert"
                )
                
                configurationToggle(
                    "Annotations",
                    binding: $appState.currentConfiguration.display.enableAnnotations,
                    icon: "text.bubble.fill"
                )
                
                configurationToggle(
                    "Hardware Acceleration",
                    binding: $appState.currentConfiguration.performance.useHardwareAcceleration,
                    icon: "speedometer"
                )
                
                // Feature-specific toggles
                featureSpecificToggles
            }
        }
    }
    
    @ViewBuilder
    private func configurationToggle(_ title: String, binding: Binding<Bool>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(binding.wrappedValue ? .green : .secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            // Use SafeToggleSwitch for a switch-like appearance
            SafeToggleSwitch("", isOn: binding)
        }
    }
    
    // MARK: - Feature-Specific Configuration
    
    @ViewBuilder
    private var featureSpecificToggles: some View {
        switch selectedDemo {
        case .syntaxHighlighting:
            configurationToggle(
                "Hardware Acceleration",
                binding: $appState.currentConfiguration.performance.useHardwareAcceleration,
                icon: "bolt.fill"
            )
            
        case .codeCompletion:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Advanced completion features coming soon")
                        .font(.caption)
                }
            }
            
        case .annotations:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Advanced annotation features coming soon")
                        .font(.caption)
                }
            }
            
        case .searchReplace:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Advanced search features coming soon")
                        .font(.caption)
                }
            }
            
        case .multiCursor:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Multi-cursor features coming soon")
                        .font(.caption)
                }
            }
            
        case .performance:
            configurationToggle(
                "Smooth Scrolling",
                binding: $appState.currentConfiguration.performance.smoothScrolling,
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }
    
    // MARK: - Performance Insights Section
    
    @ViewBuilder
    private var performanceInsightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Insights")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                performanceMetric("Rendering FPS", value: String(format: "%.1f", performanceMetrics.renderingFPS))
                performanceMetric("Memory Usage", value: String(format: "%.1f MB", performanceMetrics.memoryUsageMB))
                performanceMetric("Cache Hit Rate", value: String(format: "%.1f%%", performanceMetrics.cacheHitRate))
                performanceMetric("Active Features", value: "\(performanceMetrics.activeFeatures)")
            }
        }
    }
    
    @ViewBuilder
    private func performanceMetric(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Performance Monitor View
    
    @ViewBuilder
    private var performanceMonitorView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Performance Monitor")
                    .font(.headline)
                Spacer()
                Text("Real-time Metrics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                performanceGauge("CPU", value: performanceMetrics.cpuUsage, color: .blue)
                performanceGauge("Memory", value: performanceMetrics.memoryUsage, color: .green)
                performanceGauge("GPU", value: performanceMetrics.gpuUsage, color: .purple)
                performanceGauge("Cache", value: performanceMetrics.cacheHitRate, color: .orange)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("FPS: \(String(format: "%.1f", performanceMetrics.renderingFPS))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Latency: \(String(format: "%.1f", performanceMetrics.responseLatency))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColors.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func performanceGauge(_ title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Feature Highlight Overlay
    
    @ViewBuilder
    private var featureHighlightOverlay: some View {
        if animationState == .running {
            VStack(spacing: 8) {
                Image(systemName: selectedDemo.icon)
                    .font(.title2)
                    .foregroundColor(selectedDemo.accentColor)
                    .scaleEffect(animationState == .running ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animationState)
                
                Text("Feature Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedDemo.accentColor)
            }
            .padding(12)
            .background(Color(PlatformColors.systemBackground).opacity(0.9))
            .cornerRadius(8)
            .shadow(radius: 4)
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var demoConfiguration: EditorConfiguration {
        var config = appState.currentConfiguration
        
        // Apply demo-specific configuration enhancements
        switch selectedDemo {
        case .syntaxHighlighting:
            config.display.enableSyntaxHighlighting = true
            config.performance.useHardwareAcceleration = true
            
        case .codeCompletion:
            config.behavior.enableCodeCompletion = true
            
        case .annotations:
            config.display.enableAnnotations = true
            
        case .searchReplace:
            // Search and replace features will be available in future version
            break
            
        case .multiCursor:
            // Multi-cursor features will be available in future version
            break
            
        case .performance:
            config.performance.useHardwareAcceleration = true
            config.performance.smoothScrolling = true
        }
        
        return config
    }
    
    // MARK: - Helper Methods
    
    private func loadDemoForCurrentFeature() {
        let demoCode = selectedDemo.sampleCode
        appState.setCustomCode(demoCode)
    }
    
    private func startAnimation() {
        animationState = .running
    }
    
    private func stopAnimation() {
        animationState = .idle
    }
    
    private func resetDemo() {
        stopAnimation()
        loadDemoForCurrentFeature()
        appState.currentConfiguration = EditorConfiguration.default
    }
    
    private func startPerformanceMonitoring() {
        // Simulate performance monitoring
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        withAnimation(.easeInOut(duration: 0.3)) {
            performanceMetrics.renderingFPS = Double.random(in: 58...62)
            performanceMetrics.memoryUsageMB = Double.random(in: 45...65)
            performanceMetrics.cpuUsage = Double.random(in: 15...35)
            performanceMetrics.memoryUsage = Double.random(in: 40...70)
            performanceMetrics.gpuUsage = Double.random(in: 20...45)
            performanceMetrics.cacheHitRate = Double.random(in: 85...95)
            performanceMetrics.responseLatency = Double.random(in: 1.5...3.2)
            performanceMetrics.activeFeatures = Int.random(in: 5...8)
        }
    }
}

// MARK: - Supporting Types

enum FeatureDemo: String, CaseIterable {
    case syntaxHighlighting = "syntax"
    case codeCompletion = "completion"
    case annotations = "annotations"
    case searchReplace = "search"
    case multiCursor = "multicursor"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .syntaxHighlighting: return "Syntax Highlighting"
        case .codeCompletion: return "Code Completion"
        case .annotations: return "Annotations"
        case .searchReplace: return "Search & Replace"
        case .multiCursor: return "Multi-Cursor Editing"
        case .performance: return "Performance Monitoring"
        }
    }
    
    var description: String {
        switch self {
        case .syntaxHighlighting: return "Advanced syntax highlighting with 15+ languages"
        case .codeCompletion: return "Smart code completion with fuzzy matching"
        case .annotations: return "TODO/FIXME/NOTE detection with hover popups"
        case .searchReplace: return "Powerful search and replace with regex support"
        case .multiCursor: return "Multiple cursor editing for productivity"
        case .performance: return "Real-time performance monitoring and optimization"
        }
    }
    
    var explanation: String {
        switch self {
        case .syntaxHighlighting:
            return "Our syntax highlighting system supports 15+ programming languages with SwiftSyntax " +
                   "integration for Swift and regex-based highlighting for other languages. Features " +
                   "hardware acceleration and viewport-based rendering for optimal performance."
            
        case .codeCompletion:
            return "Intelligent code completion provides context-aware suggestions with fuzzy " +
                   "matching algorithms. Supports symbol lookup, method signatures, and smart " +
                   "filtering based on typing patterns."
            
        case .annotations:
            return "Automatic detection of TODO, FIXME, NOTE, WARNING, and ERROR comments in " +
                   "your code. Displays visual badges and provides hover popups with detailed " +
                   "information and styling."
            
        case .searchReplace:
            return "Advanced search and replace functionality with full regex support, case " +
                   "sensitivity options, and whole word matching. Highlights all matches in " +
                   "real-time as you type."
            
        case .multiCursor:
            return "Edit multiple locations simultaneously with multi-cursor support. Add cursors " +
                   "with smart selection, edit identical text in multiple places, and boost " +
                   "your productivity."
            
        case .performance:
            return "Real-time performance monitoring tracks rendering FPS, memory usage, CPU " +
                   "utilization, and cache hit rates. Provides insights for optimization and " +
                   "debugging."
        }
    }
    
    var capabilities: [String] {
        switch self {
        case .syntaxHighlighting:
            return [
                "15+ programming languages supported",
                "SwiftSyntax AST-based highlighting for Swift",
                "Regex-based highlighting for other languages",
                "Hardware acceleration support",
                "Viewport-based rendering optimization",
                "Custom theme support"
            ]
            
        case .codeCompletion:
            return [
                "Context-aware suggestions",
                "Fuzzy matching algorithm",
                "Symbol and method lookup",
                "Smart filtering and ranking",
                "Debounced input handling",
                "Performance monitoring"
            ]
            
        case .annotations:
            return [
                "Automatic comment detection",
                "5 annotation types supported",
                "Visual badge indicators",
                "Hover popup details",
                "Custom styling per type",
                "Performance tested with large files"
            ]
            
        case .searchReplace:
            return [
                "Full regex support",
                "Case sensitivity toggle",
                "Whole word matching",
                "Real-time highlighting",
                "Replace all functionality",
                "Search history"
            ]
            
        case .multiCursor:
            return [
                "Multiple simultaneous cursors",
                "Smart selection patterns",
                "Identical text editing",
                "Keyboard shortcuts",
                "Visual cursor indicators",
                "Undo/redo support"
            ]
            
        case .performance:
            return [
                "Real-time FPS monitoring",
                "Memory usage tracking",
                "CPU utilization metrics",
                "Cache hit rate analysis",
                "Response latency measurement",
                "Feature usage statistics"
            ]
        }
    }
    
    var icon: String {
        switch self {
        case .syntaxHighlighting: return "paintbrush.fill"
        case .codeCompletion: return "text.insert"
        case .annotations: return "text.bubble.fill"
        case .searchReplace: return "magnifyingglass"
        case .multiCursor: return "selection.pin.in.out"
        case .performance: return "speedometer"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .syntaxHighlighting: return .blue
        case .codeCompletion: return .green
        case .annotations: return .orange
        case .searchReplace: return .purple
        case .multiCursor: return .red
        case .performance: return .cyan
        }
    }
    
    var preferredLanguage: String {
        switch self {
        case .syntaxHighlighting: return "swift"
        case .codeCompletion: return "typescript"
        case .annotations: return "python"
        case .searchReplace: return "javascript"
        case .multiCursor: return "rust"
        case .performance: return "go"
        }
    }
    
    var sampleCode: String {
        switch self {
        case .syntaxHighlighting:
            return """
            import SwiftUI
            import Foundation

            // Syntax highlighting demo with various Swift features
            struct AdvancedSyntaxDemo: View {
                @State private var items: [String] = []
                @ObservedObject var viewModel = DemoViewModel()
                
                var body: some View {
                    NavigationView {
                        List(items, id: \\.self) { item in
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(item)
                                    .font(.headline)
                                Spacer()
                                SafeButton(action: {
                                    performAction(item)
                                }) {
                                    Text("Action")
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .navigationTitle("Demo")
                        .onAppear {
                            loadItems()
                        }
                    }
                }
                
                private func loadItems() {
                    items = ["Swift", "Python", "JavaScript", "TypeScript"]
                }
                
                private func performAction(_ item: String) {
                    print("Action for: \\(item)")
                }
            }

            class DemoViewModel: ObservableObject {
                @Published var isLoading = false
                
                func fetchData() async {
                    isLoading = true
                    defer { isLoading = false }
                    
                    do {
                        let data = try await loadRemoteData()
                        await MainActor.run {
                            // Update UI
                        }
                    } catch {
                        print("Error: \\(error)")
                    }
                }
                
                private func loadRemoteData() async throws -> Data {
                    // Simulate network call
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    return Data()
                }
            }
            """
            
        case .codeCompletion:
            return """
            interface UserRepository {
                findById(id: string): Promise<User | null>;
                create(user: CreateUserRequest): Promise<User>;
                update(id: string, updates: UpdateUserRequest): Promise<User>;
                delete(id: string): Promise<boolean>;
                findByEmail(email: string): Promise<User | null>;
            }

            class DatabaseUserRepository implements UserRepository {
                constructor(private db: Database) {}
                
                async findById(id: string): Promise<User | null> {
                    // Type 'this.db.' to see completion suggestions
                    const result = await this.db.
                    
                    // Type 'user.' to see User properties
                    if (result) {
                        const user = result as User;
                        return user.
                    }
                    
                    return null;
                }
                
                async create(request: CreateUserRequest): Promise<User> {
                    // Type 'request.' to see available properties
                    const user = new User({
                        id: generateId(),
                        name: request.
                        email: request.
                        createdAt: new Date()
                    });
                    
                    // Code completion for method calls
                    await this.db.
                    
                    return user;
                }
                
                async update(id: string, updates: UpdateUserRequest): Promise<User> {
                    const existingUser = await this.findById(id);
                    if (!existingUser) {
                        throw new Error('User not found');
                    }
                    
                    // Smart completion for object spreading
                    const updatedUser = {
                        ...existingUser,
                        ...updates,
                        updatedAt: new Date()
                    };
                    
                    return updatedUser;
                }
            }
            """
            
        case .annotations:
            return """
            import asyncio
            import logging
            from typing import List, Dict, Optional

            # TODO: Add comprehensive error handling
            # FIXME: Memory leak in connection pool
            # NOTE: This is a demonstration of the annotation system
            # WARNING: Performance bottleneck in data processing
            # ERROR: Critical bug in authentication logic

            class DataProcessor:
                def __init__(self):
                    self.logger = logging.getLogger(__name__)
                    # TODO: Initialize connection pool
                    self.connections = []
                
                async def process_data(self, data: List[Dict]) -> List[Dict]:
                    # FIXME: This method is not thread-safe
                    results = []
                    
                    for item in data:
                        try:
                            # NOTE: Each item is processed individually
                            processed = await self._process_item(item)
                            results.append(processed)
                        except Exception as e:
                            # ERROR: Unhandled exception type
                            self.logger.error(f"Failed to process item: {e}")
                            # TODO: Implement retry logic
                            continue
                    
                    # WARNING: Results may be incomplete
                    return results
                
                async def _process_item(self, item: Dict) -> Dict:
                    # TODO: Add input validation
                    if not item:
                        # ERROR: No proper error handling for empty items
                        return {}
                    
                    # FIXME: Inefficient data transformation
                    transformed = {}
                    for key, value in item.items():
                        # NOTE: Custom transformation logic
                        if isinstance(value, str):
                            transformed[key] = value.upper()
                        else:
                            transformed[key] = value
                    
                    # WARNING: No data sanitization
                    return transformed
                
                def cleanup(self):
                    # TODO: Implement proper cleanup
                    # FIXME: Connections not properly closed
                    pass

            # NOTE: Usage example with annotations
            async def main():
                processor = DataProcessor()
                
                # TODO: Load data from external source
                sample_data = [
                    {"name": "Alice", "age": 30},
                    {"name": "Bob", "age": 25},
                    # WARNING: Missing validation for this data
                    {"invalid": None}
                ]
                
                try:
                    results = await processor.process_data(sample_data)
                    print(f"Processed {len(results)} items")
                    # FIXME: No proper error reporting
                except Exception as e:
                    # ERROR: Generic exception handling
                    print(f"Processing failed: {e}")
                finally:
                    # TODO: Ensure cleanup always runs
                    processor.cleanup()

            if __name__ == "__main__":
                asyncio.run(main())
            """
            
        case .searchReplace:
            return """
            const API_BASE_URL = 'https://api.example.com';
            const API_VERSION = 'v1';

            // Search for 'API' to see highlighting in action
            // Try regex patterns like 'API_\\w+' or 'const \\w+'
            // Search and replace examples:
            // Find: 'console\\.log\\(' Replace with: 'logger.debug('
            // Find: 'function (\\w+)' Replace with: 'const $1 = '

            function fetchUserData(userId) {
                console.log(`Fetching user data for ID: ${userId}`);
                
                return fetch(`${API_BASE_URL}/${API_VERSION}/users/${userId}`)
                    .then(response => {
                        console.log('API response received');
                        if (!response.ok) {
                            console.log('API request failed');
                            throw new Error('Failed to fetch user data');
                        }
                        return response.json();
                    })
                    .catch(error => {
                        console.log('Error in fetchUserData:', error);
                        throw error;
                    });
            }

            function processUserData(userData) {
                console.log('Processing user data');
                
                // Example transformations you can search/replace:
                const processedData = {
                    id: userData.id,
                    displayName: userData.name,
                    emailAddress: userData.email,
                    isActive: userData.status === 'active',
                    lastLogin: new Date(userData.last_login),
                    preferences: userData.settings || {}
                };
                
                console.log('User data processed successfully');
                return processedData;
            }

            function updateUserProfile(userId, updates) {
                console.log(`Updating profile for user ${userId}`);
                
                const requestOptions = {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${getAuthToken()}`
                    },
                    body: JSON.stringify(updates)
                };
                
                return fetch(`${API_BASE_URL}/${API_VERSION}/users/${userId}`, requestOptions)
                    .then(response => {
                        console.log('Profile update response received');
                        return response.json();
                    })
                    .then(data => {
                        console.log('Profile updated successfully');
                        return data;
                    });
            }

            // Try these search patterns:
            // 1. Search: 'console\\.log' - finds all console.log statements
            // 2. Search: 'API_\\w+' - finds API_BASE_URL and API_VERSION
            // 3. Search: 'function\\s+(\\w+)' - finds function declarations
            // 4. Search: '\\${\\w+}' - finds template literal variables
            """
            
        case .multiCursor:
            return """
            use std::collections::HashMap;
            use std::sync::{Arc, Mutex};

            // Multi-cursor editing demo
            // Try these multi-cursor operations:
            // 1. Select "user" and add cursors to all occurrences
            // 2. Select multiple "id" fields and edit them simultaneously
            // 3. Add cursors to edit multiple function parameters at once

            #[derive(Debug, Clone)]
            struct User {
                id: u64,
                name: String,
                email: String,
                status: UserStatus,
            }

            #[derive(Debug, Clone)]
            enum UserStatus {
                Active,
                Inactive,
                Suspended,
            }

            struct UserManager {
                users: Arc<Mutex<HashMap<u64, User>>>,
                next_id: Arc<Mutex<u64>>,
            }

            impl UserManager {
                fn new() -> Self {
                    Self {
                        users: Arc::new(Mutex::new(HashMap::new())),
                        next_id: Arc::new(Mutex::new(1)),
                    }
                }
                
                fn create_user(&self, name: String, email: String) -> Result<User, String> {
                    let mut users = self.users.lock().unwrap();
                    let mut next_id = self.next_id.lock().unwrap();
                    
                    let user = User {
                        id: *next_id,
                        name: name,
                        email: email,
                        status: UserStatus::Active,
                    };
                    
                    users.insert(user.id, user.clone());
                    *next_id += 1;
                    
                    Ok(user)
                }
                
                fn get_user(&self, user_id: u64) -> Option<User> {
                    let users = self.users.lock().unwrap();
                    users.get(&user_id).cloned()
                }
                
                fn update_user_status(&self, user_id: u64, status: UserStatus) -> Result<(), String> {
                    let mut users = self.users.lock().unwrap();
                    
                    if let Some(user) = users.get_mut(&user_id) {
                        user.status = status;
                        Ok(())
                    } else {
                        Err(format!("User with id {} not found", user_id))
                    }
                }
                
                fn delete_user(&self, user_id: u64) -> Result<User, String> {
                    let mut users = self.users.lock().unwrap();
                    
                    users.remove(&user_id)
                        .ok_or_else(|| format!("User with id {} not found", user_id))
                }
                
                fn list_active_users(&self) -> Vec<User> {
                    let users = self.users.lock().unwrap();
                    
                    users.values()
                        .filter(|user| matches!(user.status, UserStatus::Active))
                        .cloned()
                        .collect()
                }
            }

            // Try multi-cursor editing on these similar patterns:
            fn example_user_operations() {
                let manager = UserManager::new();
                
                // Select all "user_" prefixes and edit them together
                let user_1 = manager.create_user("Alice".to_string(), "alice@example.com".to_string());
                let user_2 = manager.create_user("Bob".to_string(), "bob@example.com".to_string());
                let user_3 = manager.create_user("Charlie".to_string(), "charlie@example.com".to_string());
                
                // Multi-cursor edit for error handling
                if let Ok(user) = user_1 {
                    println!("Created user: {:?}", user);
                }
                if let Ok(user) = user_2 {
                    println!("Created user: {:?}", user);
                }
                if let Ok(user) = user_3 {
                    println!("Created user: {:?}", user);
                }
            }
            """
            
        case .performance:
            return """
            package main

            import (
                "context"
                "fmt"
                "runtime"
                "sync"
                "time"
            )

            // Performance monitoring demo
            // This code demonstrates performance-critical operations
            // Watch the performance metrics update as you edit

            type PerformanceMetrics struct {
                RequestCount    int64
                ResponseTimes   []time.Duration
                MemoryUsage     runtime.MemStats
                GoroutineCount  int
                CPUUsage        float64
                mutex           sync.RWMutex
            }

            type PerformanceMonitor struct {
                metrics    *PerformanceMetrics
                ticker     *time.Ticker
                ctx        context.Context
                cancel     context.CancelFunc
            }

            func NewPerformanceMonitor() *PerformanceMonitor {
                ctx, cancel := context.WithCancel(context.Background())
                
                monitor := &PerformanceMonitor{
                    metrics: &PerformanceMetrics{
                        ResponseTimes: make([]time.Duration, 0, 1000),
                    },
                    ticker: time.NewTicker(100 * time.Millisecond),
                    ctx:    ctx,
                    cancel: cancel,
                }
                
                go monitor.collectMetrics()
                return monitor
            }

            func (pm *PerformanceMonitor) collectMetrics() {
                for {
                    select {
                    case <-pm.ctx.Done():
                        return
                    case <-pm.ticker.C:
                        pm.updateMetrics()
                    }
                }
            }

            func (pm *PerformanceMonitor) updateMetrics() {
                pm.metrics.mutex.Lock()
                defer pm.metrics.mutex.Unlock()
                
                // Collect memory statistics
                runtime.ReadMemStats(&pm.metrics.MemoryUsage)
                
                // Count active goroutines
                pm.metrics.GoroutineCount = runtime.NumGoroutine()
                
                // Simulate CPU usage calculation
                pm.metrics.CPUUsage = pm.calculateCPUUsage()
            }

            func (pm *PerformanceMonitor) calculateCPUUsage() float64 {
                // Simplified CPU usage calculation
                // In real implementation, this would use system calls
                start := time.Now()
                
                // Simulate some CPU work
                for i := 0; i < 10000; i++ {
                    _ = i * i
                }
                
                elapsed := time.Since(start)
                return float64(elapsed.Nanoseconds()) / 1000000 // Convert to percentage
            }

            func (pm *PerformanceMonitor) RecordRequest(duration time.Duration) {
                pm.metrics.mutex.Lock()
                defer pm.metrics.mutex.Unlock()
                
                pm.metrics.RequestCount++
                pm.metrics.ResponseTimes = append(pm.metrics.ResponseTimes, duration)
                
                // Keep only last 1000 response times
                if len(pm.metrics.ResponseTimes) > 1000 {
                    pm.metrics.ResponseTimes = pm.metrics.ResponseTimes[1:]
                }
            }

            func (pm *PerformanceMonitor) GetAverageResponseTime() time.Duration {
                pm.metrics.mutex.RLock()
                defer pm.metrics.mutex.RUnlock()
                
                if len(pm.metrics.ResponseTimes) == 0 {
                    return 0
                }
                
                var total time.Duration
                for _, duration := range pm.metrics.ResponseTimes {
                    total += duration
                }
                
                return total / time.Duration(len(pm.metrics.ResponseTimes))
            }

            func (pm *PerformanceMonitor) PrintMetrics() {
                pm.metrics.mutex.RLock()
                defer pm.metrics.mutex.RUnlock()
                
                fmt.Printf("Performance Metrics:\\n")
                fmt.Printf("  Request Count: %d\\n", pm.metrics.RequestCount)
                fmt.Printf("  Average Response Time: %v\\n", pm.GetAverageResponseTime())
                fmt.Printf("  Memory Allocated: %d bytes\\n", pm.metrics.MemoryUsage.Alloc)
                fmt.Printf("  Goroutines: %d\\n", pm.metrics.GoroutineCount)
                fmt.Printf("  CPU Usage: %.2f%%\\n", pm.metrics.CPUUsage)
            }

            // Example usage that generates performance data
            func simulateWorkload(monitor *PerformanceMonitor) {
                var wg sync.WaitGroup
                
                // Simulate concurrent requests
                for i := 0; i < 100; i++ {
                    wg.Add(1)
                    go func(requestID int) {
                        defer wg.Done()
                        
                        start := time.Now()
                        
                        // Simulate work
                        time.Sleep(time.Duration(requestID%10) * time.Millisecond)
                        
                        // Some CPU-intensive work
                        for j := 0; j < requestID*1000; j++ {
                            _ = j * j * j
                        }
                        
                        duration := time.Since(start)
                        monitor.RecordRequest(duration)
                    }(i)
                }
                
                wg.Wait()
            }

            func main() {
                monitor := NewPerformanceMonitor()
                defer monitor.cancel()
                
                fmt.Println("Starting performance monitoring demo...")
                
                // Run workload simulation
                go func() {
                    for {
                        simulateWorkload(monitor)
                        time.Sleep(2 * time.Second)
                    }
                }()
                
                // Print metrics every 5 seconds
                ticker := time.NewTicker(5 * time.Second)
                defer ticker.Stop()
                
                for i := 0; i < 6; i++ {
                    <-ticker.C
                    monitor.PrintMetrics()
                    fmt.Println("---")
                }
                
                fmt.Println("Performance monitoring demo completed.")
            }
            """
        }
    }
}

enum AnimationState {
    case idle
    case running
}

struct PerformanceMetrics {
    var renderingFPS: Double = 60.0
    var memoryUsageMB: Double = 45.2
    var cpuUsage: Double = 25.0
    var memoryUsage: Double = 55.0
    var gpuUsage: Double = 30.0
    var cacheHitRate: Double = 90.0
    var responseLatency: Double = 2.1
    var activeFeatures: Int = 6
}

// MARK: - Preview

@available(macOS 13.0, iOS 16.0, *)
struct AdvancedFeaturesShowcaseView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedFeaturesShowcaseView()
            .environmentObject(AppState())
    }
}

