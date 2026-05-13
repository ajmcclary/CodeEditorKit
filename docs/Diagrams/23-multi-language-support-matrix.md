# Multi-Language Support Matrix

This diagram provides a comprehensive matrix view of language support capabilities across all 25 concrete supported languages plus plain text in the CodeEditorPlugin framework.

```mermaid
flowchart LR
    subgraph "Language Support Matrix"
        subgraph "Compiled Languages"
            SWIFT[Swift<br/>+ Native AST Parsing<br/>+ SwiftSyntax Integration<br/>+ Folding & Symbols<br/>+ Built-in LSP<br/>⚡ <50ms completion]
            C[C<br/>+ Enhanced Completion<br/>+ Folding & Symbols<br/>* LSP clangd<br/>⚡ <100ms completion]
            CPP[C++<br/>+ Enhanced Completion<br/>+ Folding & Symbols<br/>* LSP clangd<br/>⚡ <100ms completion]
            CSHARP[C#<br/>+ Descriptor Completion<br/>+ Folding & Symbols<br/>* LSP OmniSharp<br/>⚡ Enhanced LSP]
            KOTLIN[Kotlin<br/>+ Descriptor Completion<br/>+ Folding & Symbols<br/>* LSP Kotlin<br/>⚡ Enhanced LSP]
            DART[Dart<br/>+ Descriptor Completion<br/>+ Folding & Symbols<br/>* LSP Dart<br/>⚡ Enhanced LSP]
            RUST[Rust<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP rust-analyzer<br/>⚡ 200-500ms response]
            GO[Go<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP gopls<br/>⚡ Enhanced performance]
        end

        subgraph "Dynamic Languages"
            PYTHON[Python<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP Pylsp/Pyright<br/>⚡ 150-400ms response]
            JS[JavaScript<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP tsserver<br/>⚡ 100-300ms response]
            TS[TypeScript<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP tsserver<br/>⚡ 100-300ms response]
            RUBY[Ruby<br/>+ Enhanced Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP solargraph<br/>⚡ 50-150ms response]
            PHP[PHP<br/>+ Enhanced Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP intelephense<br/>⚡ 50-150ms response]
            JAVA[Java<br/>+ Universal Completion<br/>+ Enhanced Symbols<br/>+ Folding<br/>* LSP Eclipse JDT<br/>⚡ Enhanced LSP]
            LUA[Lua<br/>+ Descriptor Completion<br/>+ Folding & Symbols<br/>* LSP LuaLS<br/>⚡ Enhanced LSP]
        end

        subgraph "Web & Markup Languages"
            HTML[HTML<br/>+ Tag/Attribute Completion<br/>+ Element Symbols<br/>+ Folding<br/>* LSP HTML LSP<br/>+ Formatting<br/>⚡ Enhanced LSP]
            CSS[CSS<br/>+ Property Completion<br/>+ Selector Symbols<br/>+ Folding<br/>* LSP CSS LSP<br/>+ Formatting<br/>⚡ Enhanced LSP]
            SQL[SQL<br/>+ Query Completion<br/>+ Schema Symbols<br/>+ Folding<br/>* LSP SQL LSP<br/>+ Formatting<br/>⚡ Enhanced LSP]
            SHELL[Shell/Bash<br/>+ Command Completion<br/>+ Function Symbols<br/>+ Folding<br/>* LSP Bash LSP<br/>+ Formatting<br/>⚡ Enhanced LSP]
        end

        subgraph "Data & Configuration Languages"
            JSON[JSON<br/>+ FastJSONTokenizer<br/>+ Path Navigation<br/>+ Folding<br/>+ Native + LSP<br/>+ Formatting<br/>⚡ <10ms validation]
            YAML[YAML<br/>+ Enhanced Completion<br/>+ Anchor Symbols<br/>+ Folding<br/>* LSP YAML LSP<br/>+ Formatting<br/>⚡ <50ms response]
            XML[XML<br/>+ Enhanced Completion<br/>+ Element Symbols<br/>+ Folding<br/>* LSP XML LSP<br/>+ Formatting<br/>⚡ <50ms response]
            MD[Markdown<br/>+ Enhanced Link Completion<br/>+ Header Symbols<br/>+ Folding<br/>* LSP Marksman<br/>+ Formatting<br/>⚡ <50ms response]
            DOCKER[Dockerfile<br/>+ Instruction Highlighting<br/>+ Descriptor Completion<br/>+ Folding<br/>* LSP Dockerfile<br/>⚡ Enhanced LSP]
            TOML[TOML<br/>+ Key/Value Highlighting<br/>+ Descriptor Completion<br/>+ Folding<br/>* LSP taplo<br/>⚡ Enhanced LSP]
        end
    end

    subgraph "LSP Infrastructure"
        LSP_CLIENT[LSPClient<br/>+ Observable Client<br/>+ Server Communication]
        LSP_REGISTRY[LSPClientRegistry<br/>+ Server Registration<br/>+ Server Lookup]
        UNIVERSAL_COMPLETION[UniversalCompletionProvider<br/>+ Language Metadata<br/>+ Fallback Completion]
    end

    subgraph "Performance Tiers"
        TIER1[Tier 1: Native<br/>Swift + JSON<br/>Direct parsing<br/><50ms response]
        TIER2[Tier 2: LSP Enhanced<br/>Major languages<br/>Comprehensive LSP<br/>100-500ms response]
        TIER3[Tier 3: Pattern Enhanced<br/>Enhanced completion<br/>Symbol providers<br/>50-150ms response]
    end

    subgraph "Support Legend"
        LEGEND[+ Full Support<br/>* Enhanced LSP<br/>⚡ Performance Metric]
    end

    %% Styling - Dark mode friendly colors
    classDef compiled fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef dynamic fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef web fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef data fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef infrastructure fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef performance fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F
    classDef legend fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F

    class SWIFT compiled
    class C compiled
    class CPP compiled
    class CSHARP compiled
    class KOTLIN compiled
    class DART compiled
    class RUST compiled
    class GO compiled
    class PYTHON dynamic
    class JS dynamic
    class TS dynamic
    class RUBY dynamic
    class PHP dynamic
    class JAVA dynamic
    class LUA dynamic
    class HTML web
    class CSS web
    class SQL web
    class SHELL web
    class JSON data
    class YAML data
    class XML data
    class MD data
    class DOCKER data
    class TOML data
    class LSP_CLIENT infrastructure
    class LSP_REGISTRY infrastructure
    class UNIVERSAL_COMPLETION infrastructure
    class TIER1 performance
    class TIER2 performance
    class TIER3 performance
    class LEGEND legend
```

## Language Capability Details

```mermaid
classDiagram
    %% Real completion provider base
    class CompletionProvider {
        <<protocol>>
        +provideCompletions()
    }

    class UniversalCompletionProvider {
        <<base class>>
        +provideCompletions()
        +buildCompletions()
    }

    class CompletionProviderRegistry {
        <<registry>>
        +providers: [String: CompletionProvider]
        +register()
        +getProvider()
        +ensureProvider()
    }

    class LanguageProviderFactory {
        <<factory>>
        +createProvider()
    }

    class LanguageMetadataRegistry {
        <<metadata registry>>
        +getLanguageInfo()
        +updateMetadata()
    }

    class UniversalCompletionProvider {
        <<universal>>
        +languageMetadata: [String: LanguageMetadata]
        +provideCompletions()
    }

    class LSPCompletionProvider {
        <<lsp>>
        +lspManager: LSPManager
        +provideCompletions()
    }

    class LSPClientRegistry {
        <<registry>>
        +registeredServers
        +resolveServerPath()
        +registerServer()
    }

    class LSPClient {
        <<observable>>
        +serverCommunication
    }

    class SharedCompletionBuilder {
        <<shared>>
        +buildKeywordCompletions()
        +buildSnippetCompletions()
    }

    class LanguageMemberCompletions {
        <<member>>
        +analyzeMembers()
    }

    %% Relationships
    CompletionProvider <|.. UniversalCompletionProvider : implements
    CompletionProvider <|.. UniversalCompletionProvider : implements
    CompletionProvider <|.. LSPCompletionProvider : implements

    CompletionProviderRegistry --> CompletionProvider : contains
    LanguageProviderFactory --> CompletionProviderRegistry : manages
    LanguageProviderFactory --> LanguageMetadataRegistry : uses
    LanguageProviderFactory --> SharedCompletionBuilder : coordinates
    LanguageProviderFactory --> UniversalCompletionProvider : fallback

    LSPCompletionProvider --> LSPClientRegistry : uses
    LSPClientRegistry --> LSPClient : manages
    SharedCompletionBuilder --> LanguageMemberCompletions : uses

    %% Styling - Dark mode friendly colors
    classDef protocol fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef base fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef registry fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef factory fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef lsp fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef shared fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F

    class CompletionProvider protocol
    class UniversalCompletionProvider base
    class CompletionProviderRegistry registry
    class LanguageProviderFactory factory
    class LanguageMetadataRegistry registry
    class UniversalCompletionProvider base
    class LSPCompletionProvider lsp
    class LSPClientRegistry registry
    class LSPClient registry
    class SharedCompletionBuilder shared
    class LanguageMemberCompletions shared
```

## Language Support Tiers

### Tier 1: Native Support (High Performance Integration)
- **Swift**: Complete native integration with SwiftSyntax, direct AST parsing, <50ms completion
- **JSON**: FastJSONTokenizer with native parsing, <10ms validation

### Tier 2: LSP Enhanced (Comprehensive External Server Integration)
- **TypeScript/JavaScript**: Enhanced LSP with client registry, 100-300ms response time
- **Python**: Enhanced LSP with retry configuration and health monitoring, 150-400ms response time
- **Rust**: Enhanced LSP with rust-analyzer, 200-500ms response time
- **Go**: Enhanced LSP with gopls and automatic path resolution
- **Java**: Enhanced LSP with Eclipse JDT and universal completion provider
- **HTML/CSS**: Enhanced LSP with tag/property validation
- **SQL**: Enhanced LSP with query validation and schema symbol support
- **Shell/Bash**: Enhanced LSP with command completion and function symbol navigation

### Tier 3: Enhanced Pattern-Based (Improved Completion and Symbol Providers)
- **Ruby**: Enhanced pattern matching with symbol providers and universal completion
- **PHP**: Enhanced pattern-based completion with member completion features
- **YAML**: Enhanced schema validation with folding and anchor symbol support
- **XML**: Enhanced element completion with symbol navigation and validation
- **Markdown**: Enhanced link resolution with header symbols

### Tier 4: Basic LSP Support
- **C**: Enhanced completion with clangd LSP integration

## Feature Comparison Matrix

| Language | Completion | Symbols | Folding | LSP |
|----------|------------|---------|---------|-----|
| Swift | ✅ Native AST | ✅ Full | ✅ Full | ✅ Built-in |
| JavaScript | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ tsserver |
| TypeScript | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ tsserver |
| Python | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ Pylsp/Pyright |
| Go | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ gopls |
| Rust | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ rust-analyzer |
| C | ✅ Enhanced | ✅ Full | ✅ Full | ⚡ clangd |
| Java | ✅ Universal | ✅ Enhanced | ✅ Full | ⚡ Eclipse JDT |
| HTML | ✅ Tag/Attr | ✅ Element | ✅ Full | ⚡ HTML LSP |
| CSS | ✅ Property | ✅ Selector | ✅ Full | ⚡ CSS LSP |
| SQL | ✅ Query | ✅ Schema | ✅ Full | ⚡ SQL LSP |
| Shell | ✅ Command | ✅ Function | ✅ Full | ⚡ Bash LSP |
| Ruby | ✅ Enhanced | ✅ Enhanced | ✅ Full | ⚡ Solargraph |
| PHP | ✅ Enhanced | ✅ Enhanced | ✅ Full | ⚡ Intelephense |
| JSON | ✅ FastToken | ✅ Path | ✅ Full | ✅ Native+LSP |
| YAML | ✅ Enhanced | ✅ Anchor | ✅ Full | ⚡ YAML LSP |
| XML | ✅ Enhanced | ✅ Element | ✅ Full | ⚡ XML LSP |
| Markdown | ✅ Enhanced | ✅ Header | ✅ Full | ⚡ Marksman |

## Performance Characteristics

### High Performance Languages (Native Integration)
- **Swift**: Direct SwiftSyntax AST parsing, <50ms completion response
- **JSON**: FastJSONTokenizer with native parsing, <10ms validation

### Enhanced Performance Languages (LSP Integration)
- **TypeScript**: LSP with client registry, 100-300ms response time
- **Python**: LSP with retry configuration, 150-400ms response time
- **Rust**: rust-analyzer with health monitoring, 200-500ms response time
- **Go/Java/HTML/CSS/SQL/Shell**: LSP infrastructure with automatic path resolution

### Optimized Performance Languages (Pattern-Based)
- **Ruby/PHP**: Pattern matching with universal completion provider, 50-150ms response time
- **YAML/XML/Markdown**: Parsing with symbol providers, <50ms response time
- **C**: Clang-based parsing, <100ms completion response

## LSP Infrastructure

### LSP Client Registry
- **Server Registration**: Management of language server instances
- **Server Lookup**: Resolution of language server paths
- **LSPClient**: Observable client for server communication

### Universal Completion Provider
- **Language Metadata Support**: Rich metadata for enhanced completion contexts
- **Fallback Completion**: Unified completion experience when language-specific providers are unavailable

### Shared Infrastructure
- **CompletionProviderRegistry**: Central registration and lookup of completion providers
- **LanguageProviderFactory**: Factory for creating language-specific providers
- **SharedCompletionBuilder**: Common completion building logic
- **LanguageMemberCompletions**: Member completion resolution

## Extension Strategy

### Adding New Languages
1. **Assess Support Level**: Determine appropriate tier based on available tooling
2. **Implementation Path**: Choose native, enhanced LSP, or pattern-based approach
3. **Capability Mapping**: Define supported capabilities and performance targets
4. **Infrastructure Integration**: Leverage universal completion and symbol providers
5. **Testing Strategy**: Create comprehensive test suite with performance benchmarks

### LSP Integration Process
1. **LSPClientRegistry**: Automatic discovery and path resolution for language servers
2. **LSPClient**: Observable client for server communication
3. **UniversalCompletionProvider**: Unified completion system with language metadata support
4. **SharedCompletionBuilder**: Reusable keyword and snippet completion infrastructure

## Benefits

1. **Comprehensive Coverage**: Support for 25 concrete programming languages with enhanced capabilities
2. **Performance Tiers**: Native integration for Swift/JSON, enhanced LSP for major languages, improved pattern-based for others
3. **LSP Infrastructure**: Client registry with server registration and lookup
4. **Universal Completion System**: Unified completion provider with language metadata
5. **Extensible Design**: Easy addition of new languages
6. **Standards Compliant**: LSP integration ensures compatibility with ecosystem tools
7. **Performance Optimized**: Appropriate performance targets for each language tier
8. **Consistent Experience**: Unified API and user experience across all supported languages
