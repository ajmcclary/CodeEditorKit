import Foundation

extension ThemeFamily {
    /// Decode from raw JSON bytes. Throws on parse failure or missing
    /// required top-level fields. Lenient on individual color keys —
    /// missing or malformed values fall back to internal defaults and
    /// accumulate in the `WarningCollector` but do not throw.
    public init(jsonData data: Data) throws {
        let (family, _) = try Self.decode(data: data)
        self = family
    }

    /// Decode from a file URL. Throws on I/O or parse failure.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(jsonData: data)
    }

    /// Decode + return any non-fatal warnings recorded during decoding.
    public static func loaded(jsonData data: Data) throws -> (ThemeFamily, [ThemeWarning]) {
        try decode(data: data)
    }

    /// Decode from a file URL + return any non-fatal warnings.
    public static func loaded(contentsOf url: URL) throws -> (ThemeFamily, [ThemeWarning]) {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    /// Bundled-resource lookup by file basename (without extension).
    /// In sub-project 2 only `"zed-trek"` resolves. Returns nil if the
    /// resource is missing or fails to parse.
    public static func bundled(_ name: String) -> ThemeFamily? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json")
        else { return nil }
        return try? ThemeFamily(contentsOf: url)
    }

    private static func decode(data: Data) throws -> (ThemeFamily, [ThemeWarning]) {
        let collector = WarningCollector()
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = collector
        let family = try decoder.decode(ThemeFamily.self, from: data)
        return (family, collector.warnings)
    }
}

extension Theme {
    /// Convenience: load a specific variant from a bundled family.
    /// Returns nil if family or variant missing.
    public static func bundled(family: String, variant: String) -> Theme? {
        ThemeFamily.bundled(family)?.theme(named: variant)
    }

    /// Library default. Resolves to `"LCARS Dark"` from the `"zed-trek"`
    /// bundle; falls back to `Theme.fallback(appearance: .dark)` if the
    /// bundle is somehow absent (build error in normal use).
    ///
    /// The bundled JSON (~5.5k lines) is decoded once at first access and
    /// cached for the process lifetime — every `CodeEditor.init` defaults
    /// the theme to this value, so re-decoding per access would put the
    /// parser on every SwiftUI body's hot path.
    public static let lcarsDark: Theme = bundled(family: "zed-trek", variant: "LCARS Dark")
        ?? Theme.fallback(appearance: .dark)
}
