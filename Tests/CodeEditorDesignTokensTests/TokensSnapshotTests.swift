import Testing
import SnapshotTesting
import Foundation
@testable import CodeEditorDesignTokens

/// Aggregates every public static token into a single Codable structure.
/// Snapshot equality of this structure means no token has drifted.
private struct TokensManifest: Encodable {

    let schemaVersion = Tokens.schemaVersion

    struct Typography: Encodable {
        let fontSansStack = Tokens.Typography.fontSansStack
        let fontDisplayStack = Tokens.Typography.fontDisplayStack
        let fontRoundedStack = Tokens.Typography.fontRoundedStack
        let fontMonoStack = Tokens.Typography.fontMonoStack
        let sizes: [String: Double] = [
            "displayXL": Tokens.Typography.Size.displayXL,
            "displayLG": Tokens.Typography.Size.displayLG,
            "displayMD": Tokens.Typography.Size.displayMD,
            "displaySM": Tokens.Typography.Size.displaySM,
            "titleXL": Tokens.Typography.Size.titleXL,
            "titleLG": Tokens.Typography.Size.titleLG,
            "titleMD": Tokens.Typography.Size.titleMD,
            "titleSM": Tokens.Typography.Size.titleSM,
            "headingLG": Tokens.Typography.Size.headingLG,
            "headingMD": Tokens.Typography.Size.headingMD,
            "bodyLG": Tokens.Typography.Size.bodyLG,
            "bodyMD": Tokens.Typography.Size.bodyMD,
            "bodySM": Tokens.Typography.Size.bodySM,
            "captionLG": Tokens.Typography.Size.captionLG,
            "captionMD": Tokens.Typography.Size.captionMD,
            "overline": Tokens.Typography.Size.overline
        ]
        let weights: [String: Int] = [
            "regular": Tokens.Typography.Weight.regular,
            "medium": Tokens.Typography.Weight.medium,
            "semibold": Tokens.Typography.Weight.semibold,
            "bold": Tokens.Typography.Weight.bold
        ]
        let lineHeights: [String: Double] = [
            "tight": Tokens.Typography.LineHeight.tight,
            "normal": Tokens.Typography.LineHeight.normal,
            "relaxed": Tokens.Typography.LineHeight.relaxed
        ]
        let trackingCaps = Tokens.Typography.Tracking.caps
    }

    struct Spacing: Encodable {
        let xxxs = Tokens.Spacing.xxxs
        let xxs = Tokens.Spacing.xxs
        let xs = Tokens.Spacing.xs
        let sm = Tokens.Spacing.sm
        let smMd = Tokens.Spacing.smMd
        let md = Tokens.Spacing.md
        let lg = Tokens.Spacing.lg
        let xl = Tokens.Spacing.xl
        let xxl = Tokens.Spacing.xxl
        let xxxl = Tokens.Spacing.xxxl
        let cardPadding = Tokens.Spacing.cardPadding
        let section = Tokens.Spacing.section
        let content = Tokens.Spacing.content
    }

    struct Shape: Encodable {
        let radii: [String: Double] = [
            "xs": Tokens.Shape.radiusXS, "sm": Tokens.Shape.radiusSM,
            "md": Tokens.Shape.radiusMD, "lg": Tokens.Shape.radiusLG,
            "xl": Tokens.Shape.radiusXL, "xxl": Tokens.Shape.radiusXXL,
            "chip": Tokens.Shape.radiusChip,
            "window": Tokens.Shape.radiusWindow,
            "full": Tokens.Shape.radiusFull
        ]
        let strokes: [String: Double] = [
            "hairline": Tokens.Shape.strokeHairline,
            "thin": Tokens.Shape.strokeThin,
            "medLight": Tokens.Shape.strokeMedLight,
            "medium": Tokens.Shape.strokeMedium,
            "thick": Tokens.Shape.strokeThick,
            "ring": Tokens.Shape.strokeRing
        ]
    }

    struct Opacity: Encodable {
        let scale: [String: Double] = [
            "faint": Tokens.Opacity.faint, "dim": Tokens.Opacity.dim,
            "subtle": Tokens.Opacity.subtle, "mist": Tokens.Opacity.mist,
            "soft": Tokens.Opacity.soft, "tint": Tokens.Opacity.tint,
            "glassFill": Tokens.Opacity.glassFill,
            "glassBorder": Tokens.Opacity.glassBorder,
            "glassHighlight": Tokens.Opacity.glassHighlight,
            "light": Tokens.Opacity.light,
            "disabled": Tokens.Opacity.disabled,
            "medium": Tokens.Opacity.medium,
            "strong": Tokens.Opacity.strong,
            "heavy": Tokens.Opacity.heavy,
            "near": Tokens.Opacity.near
        ]
    }

    struct Animation: Encodable {
        let durationsMS: [String: Int] = [
            "instant": 100, "fast": 150, "quick": 200, "drawer": 250,
            "control": 300, "page": 350, "section": 400, "screen": 500,
            "verySlow": 600
        ]
        let easings: [String: [Double]] = [
            "easeOutSoft": [
                Tokens.Animation.easeOutSoft.x1, Tokens.Animation.easeOutSoft.y1,
                Tokens.Animation.easeOutSoft.x2, Tokens.Animation.easeOutSoft.y2
            ],
            "easeInOutSoft": [
                Tokens.Animation.easeInOutSoft.x1, Tokens.Animation.easeInOutSoft.y1,
                Tokens.Animation.easeInOutSoft.x2, Tokens.Animation.easeInOutSoft.y2
            ],
            "easeSpringSnappy": [
                Tokens.Animation.easeSpringSnappy.x1, Tokens.Animation.easeSpringSnappy.y1,
                Tokens.Animation.easeSpringSnappy.x2, Tokens.Animation.easeSpringSnappy.y2
            ]
        ]
    }

    struct Size: Encodable {
        let icons: [String: Double] = [
            "indicator": Tokens.Size.Icon.indicator, "micro": Tokens.Size.Icon.micro,
            "xs": Tokens.Size.Icon.xs, "sm": Tokens.Size.Icon.sm,
            "md": Tokens.Size.Icon.md, "lg": Tokens.Size.Icon.lg,
            "xl": Tokens.Size.Icon.xl, "xxl": Tokens.Size.Icon.xxl
        ]
        let touch: [String: Double] = [
            "min": Tokens.Size.Touch.min,
            "comfortable": Tokens.Size.Touch.comfortable,
            "row": Tokens.Size.Touch.row,
            "large": Tokens.Size.Touch.large
        ]
        let avatar: [String: Double] = [
            "xs": Tokens.Size.Avatar.xs, "sm": Tokens.Size.Avatar.sm,
            "md": Tokens.Size.Avatar.md, "lg": Tokens.Size.Avatar.lg,
            "xl": Tokens.Size.Avatar.xl
        ]
    }

    struct Palette: Encodable {
        let accentDark = Tokens.Palette.Accent.dark.hexString
        let accentLight = Tokens.Palette.Accent.light.hexString
        let accentContrast = Tokens.Palette.Accent.contrast.hexString
        let hoverDark = Tokens.Palette.Accent.hoverDark.hexString
        let pressedDark = Tokens.Palette.Accent.pressedDark.hexString
        let hoverLight = Tokens.Palette.Accent.hoverLight.hexString
        let pressedLight = Tokens.Palette.Accent.pressedLight.hexString
        let tint10Dark = Tokens.Palette.Accent.tint10Dark.hexString
        let tint15Dark = Tokens.Palette.Accent.tint15Dark.hexString
        let tint20Dark = Tokens.Palette.Accent.tint20Dark.hexString
        let tint25Dark = Tokens.Palette.Accent.tint25Dark.hexString
        let statusSuccessDark = Tokens.Palette.Status.successDark.hexString
        let statusWarningDark = Tokens.Palette.Status.warningDark.hexString
        let statusErrorDark = Tokens.Palette.Status.errorDark.hexString
        let statusInfoDark = Tokens.Palette.Status.infoDark.hexString
        let statusCautionDark = Tokens.Palette.Status.cautionDark.hexString
        let ansiBlack = Tokens.Palette.ANSI.black.hexString
        let ansiRed = Tokens.Palette.ANSI.red.hexString
        let ansiGreen = Tokens.Palette.ANSI.green.hexString
        let ansiYellow = Tokens.Palette.ANSI.yellow.hexString
        let ansiBlue = Tokens.Palette.ANSI.blue.hexString
        let ansiMagenta = Tokens.Palette.ANSI.magenta.hexString
        let ansiCyan = Tokens.Palette.ANSI.cyan.hexString
        let ansiWhite = Tokens.Palette.ANSI.white.hexString
    }

    let typography = Typography()
    let spacing = Spacing()
    let shape = Shape()
    let opacity = Opacity()
    let animation = Animation()
    let size = Size()
    let palette = Palette()
}

@Suite("Tokens snapshot drift")
struct TokensSnapshotTests {

    @Test("manifest matches committed snapshot")
    func tokensSnapshot() {
        let manifest = TokensManifest()
        assertSnapshot(of: manifest, as: .json)
    }
}
