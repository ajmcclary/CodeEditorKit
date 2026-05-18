@testable import CodeEditorSwiftUI
import CodeEditorUI
import Foundation
import Testing

@Suite("PlatformGlassSurface role enumeration")
struct PlatformGlassSurfaceTests {
    @Test("Role declares all five expected cases")
    func roleCases() {
        let cases: [PlatformGlassSurface.Role] = [
            .titleBar, .tabBar, .statusBar, .panel, .popover
        ]
        #expect(Set(cases).count == 5)
    }

    @Test("Role is Sendable + Hashable")
    func roleConforms() {
        let role: any (Sendable & Hashable) = PlatformGlassSurface.Role.titleBar
        _ = role
    }
}
