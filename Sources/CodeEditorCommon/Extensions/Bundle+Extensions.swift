// swiftlint:disable missing_docs
import Foundation

#if canImport(XCTest)
extension Bundle {
    public var isXCTestRunner: Bool {
        #if DEBUG
        return NSClassFromString("XCTest") != nil
        #else
        return false
        #endif
    }

    public static var testBundle: Bundle? {
        allBundles.first {
            $0.bundlePath.components(separatedBy: "/").last?.contains("Tests.xctest") == true
        }
    }
}
#endif

// swiftlint:enable missing_docs
