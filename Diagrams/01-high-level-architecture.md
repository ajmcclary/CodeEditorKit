# High-Level Architecture Diagram

This diagram shows the overall architecture of the CodeEditorPlugin framework, illustrating the main layers and their relationships.

```mermaid
graph TB
    %% SwiftUI Layer
    subgraph "SwiftUI Integration"
        SE[CodeEditor<br/>SwiftUI View]
        ENV[Environment Values]
        MOD[View Modifiers]
    end

    %% Core Layer
    subgraph "Core Components"
        API[CodeEditorAPI<br/>Protocol]
        CEV[CodeEditorView<br/>NSTextView/UITextView]
        CCV[CodeEditorContainerView]
        UES[UnifiedEventSystem]
    end

    %% Services Layer
    subgraph "Services"
        BLS[BusinessLogicServiceRegistry]
        TES[TextEditingService]
        LDS[LanguageDetectionService]
        SHS[SyntaxHighlightingService]
        CMS[CompletionManager]
        MMS[MemoryMonitor]
    end

    %% Configuration
    subgraph "Configuration"
        EC[EditorConfiguration]
        DC[Display Config]
        LC[Layout Config]
        BC[Behavior Config]
        PC[Performance Config]
    end

    %% Platform Abstraction
    subgraph "Platform Abstraction"
        PAB[Platform Capabilities]
        PV[PlatformView]
        PF[PlatformFont]
        PCL[PlatformColor]
        CPC[CrossPlatformCoordinator]
    end

    %% Features
    subgraph "Features"
        GUT[Gutter]
        MM[Minimap]
        BRA[Bracket Matching]
        FOLD[Code Folding]
        IND[Indentation]
        ANN[Annotations]
    end

    %% Language Support
    subgraph "Language Support"
        LP[Language Providers]
        SHL[Syntax Highlighters]
        CP[Completion Providers]
        TOK[Tokenizers]
    end

    %% External
    subgraph "External Integration"
        LSP[LSP Client]
        PLG[Plugin System]
        SS[SwiftSyntax]
    end

    %% Connections
    SE --> API
    SE --> ENV
    SE --> MOD
    
    API <--> CEV
    CEV --> CCV
    CCV --> UES
    
    UES <--> BLS
    BLS --> TES
    BLS --> LDS
    BLS --> SHS
    BLS --> CMS
    BLS --> MMS
    
    EC --> DC
    EC --> LC
    EC --> BC
    EC --> PC
    
    CEV --> PAB
    PAB --> PV
    PAB --> PF
    PAB --> PCL
    PAB --> CPC
    
    CCV --> GUT
    CCV --> MM
    CEV --> BRA
    CEV --> FOLD
    CEV --> IND
    CEV --> ANN
    
    SHS --> LP
    LP --> SHL
    LP --> CP
    LP --> TOK
    
    CMS --> LSP
    CEV --> PLG
    SHL --> SS
    
    ENV --> EC
    MOD --> EC
    
    %% Styling - Dark mode friendly colors
    classDef swiftui fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef core fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef service fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef config fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef platform fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef feature fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef lang fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    classDef external fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    
    class SE swiftui
    class ENV swiftui
    class MOD swiftui
    class API core
    class CEV core
    class CCV core
    class UES core
    class BLS service
    class TES service
    class LDS service
    class SHS service
    class CMS service
    class MMS service
    class EC config
    class DC config
    class LC config
    class BC config
    class PC config
    class PAB platform
    class PV platform
    class PF platform
    class PCL platform
    class CPC platform
    class GUT feature
    class MM feature
    class BRA feature
    class FOLD feature
    class IND feature
    class ANN feature
    class LP lang
    class SHL lang
    class CP lang
    class TOK lang
    class LSP external
    class PLG external
    class SS external
```

## Key Architectural Principles

1. **Layered Architecture**: Clear separation between UI (SwiftUI), Core logic, Services, and Platform abstractions
2. **Protocol-Oriented**: Core functionality defined through protocols (CodeEditorAPI)
3. **Service-Based**: Business logic encapsulated in services managed by a central registry
4. **Platform Agnostic**: Platform-specific code isolated in abstraction layer
5. **Event-Driven**: Unified event system for decoupled communication
6. **Configurable**: Comprehensive configuration system with environment integration
7. **Extensible**: Plugin system and language provider architecture for extensions