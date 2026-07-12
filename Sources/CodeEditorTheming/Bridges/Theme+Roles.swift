import CodeEditorDesignTokens

extension Theme {
    /// Text/icon color on an accent-1 (primary button) fill. CSS `--on-accent`.
    public var onAccent: Tokens.Color { platform.onAccent }
    /// Text/icon color on a diag-error (destructive button) fill. CSS `--on-danger`.
    public var onDanger: Tokens.Color { platform.onDanger }
    /// Liquid-Glass base tint for this theme. CSS `--glass-tint`.
    public var glassTint: Tokens.Color { platform.glass.tint }
}
