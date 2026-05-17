import CodeEditorPlatform
import Foundation

extension DeviceType {
    /// Recommended editor configuration based on device type
    public func recommendedConfiguration() -> EditorConfiguration {
        switch self {
        case .iPhone, .appleWatch:
            return .minimal

        case .iPad:
            var config = EditorConfiguration.default
            config.display.isLineNumbersEnabled = true
            config.display.isMinimapVisible = false
            config.display.fontSize = 14
            return config

        case .mac:
            return .default

        case .appleTV:
            var config = EditorConfiguration.presentation
            config.display.fontSize = 24
            config.display.isLineNumbersEnabled = false
            return config

        case .carPlay:
            return .readOnly

        case .visionPro:
            var config = EditorConfiguration.default
            config.display.fontSize = 16
            config.layout.lineHeightMultiple = 1.3
            return config

        default:
            return .default
        }
    }
}
