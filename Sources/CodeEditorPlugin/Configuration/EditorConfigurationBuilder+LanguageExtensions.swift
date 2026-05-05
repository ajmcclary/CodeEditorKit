import Foundation

// MARK: - Language Configuration

extension EditorConfigurationBuilder {
  /// Language-specific configuration settings
  internal struct LanguageSettings {
    let syntaxHighlighting: Bool
    let codeCompletion: Bool
    let autoIndent: Bool
    let tabWidth: Int
    let insertSpacesForTabs: Bool
    let wrapLines: Bool
    let enableSpellCheck: Bool
  }

  /// Base language settings for code languages
  internal static let baseCodeSettings = LanguageSettings(
    syntaxHighlighting: true,
    codeCompletion: true,
    autoIndent: true,
    tabWidth: 4,
    insertSpacesForTabs: true,
    wrapLines: false,
    enableSpellCheck: false
  )

  /// Base language settings for document languages
  internal static let baseDocumentSettings = LanguageSettings(
    syntaxHighlighting: true,
    codeCompletion: false,
    autoIndent: false,
    tabWidth: 4,
    insertSpacesForTabs: true,
    wrapLines: true,
    enableSpellCheck: true
  )

  /// Override values for language settings
  internal struct LanguageSettingsOverride {
    var tabWidth: Int?
    var insertSpacesForTabs: BooleanOverride = .inherit
    var syntaxHighlighting: BooleanOverride = .inherit
  }

  /// Enum to represent boolean overrides without using optional Bool
  internal enum BooleanOverride {
    case inherit
    case enable
    case disable

    func value(or defaultValue: Bool) -> Bool {
      switch self {
      case .inherit:
        return defaultValue

      case .enable:
        return true

      case .disable:
        return false
      }
    }
  }

  /// Helper to create language settings with custom overrides
  internal static func createSettings(
    base: LanguageSettings,
    overrides: LanguageSettingsOverride = LanguageSettingsOverride()
  ) -> LanguageSettings {
    LanguageSettings(
      syntaxHighlighting: overrides.syntaxHighlighting.value(or: base.syntaxHighlighting),
      codeCompletion: base.codeCompletion,
      autoIndent: base.autoIndent,
      tabWidth: overrides.tabWidth ?? base.tabWidth,
      insertSpacesForTabs: overrides.insertSpacesForTabs.value(or: base.insertSpacesForTabs),
      wrapLines: base.wrapLines,
      enableSpellCheck: base.enableSpellCheck
    )
  }

  /// Default language configurations
  internal static let languageSettings: [Language: LanguageSettings] = {
    var settings: [Language: LanguageSettings] = [:]

    // Standard 4-space languages with spaces
    let fourSpaceLanguages: [Language] = [.swift, .python, .java, .sql, .ruby, .php, .shell]
    for language in fourSpaceLanguages {
      settings[language] = baseCodeSettings
    }

    // 2-space languages
    let twoSpaceLanguages: [Language] = [.javascript, .typescript, .html, .css, .xml, .json, .yaml]
    for language in twoSpaceLanguages {
      settings[language] = createSettings(base: baseCodeSettings, overrides: LanguageSettingsOverride(tabWidth: 2))
    }

    // Tab languages
    let tabLanguages: [Language] = [.go, .rust, .c, .cpp]
    for language in tabLanguages {
      settings[language] = createSettings(base: baseCodeSettings, overrides: LanguageSettingsOverride(insertSpacesForTabs: .disable))
    }

    // Document languages
    settings[.markdown] = baseDocumentSettings
    settings[.plainText] = createSettings(base: baseDocumentSettings, overrides: LanguageSettingsOverride(syntaxHighlighting: .disable))

    return settings
  }()

  /// Configures the editor for a specific language
  /// - Parameter language: The language to optimize for
  /// - Returns: The builder for chaining
  @discardableResult
  func language(_ language: Language) -> Self {
    guard let settings = Self.languageSettings[language] else {
      // Default settings for unknown languages
      return enableSyntaxHighlighting(true)
        .enableCodeCompletion(true)
        .autoIndent(true)
        .tabWidth(4)
        .insertSpacesForTabs(true)
    }

    var builder = self
    builder = builder.enableSyntaxHighlighting(settings.syntaxHighlighting)
    builder = builder.enableCodeCompletion(settings.codeCompletion)
    builder = builder.autoIndent(settings.autoIndent)
    builder = builder.tabWidth(settings.tabWidth)
    builder = builder.insertSpacesForTabs(settings.insertSpacesForTabs)

    if settings.wrapLines {
      builder = builder.wrapLines(settings.wrapLines)
    }

    if settings.enableSpellCheck {
      builder = builder.enableSpellCheck(settings.enableSpellCheck)
    }

    return builder
  }
}
