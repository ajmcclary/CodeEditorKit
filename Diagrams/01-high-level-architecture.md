# High-Level Architecture Diagram

This diagram shows the overall architecture of the CodeEditorPlugin framework, illustrating the main layers and their relationships.

```mermaid
graph TD
    %% SwiftUI Integration Layer
    subgraph SUI [" SwiftUI Integration Layer "]
        direction TB
        SE["CodeEditor<br/>Main SwiftUI View"]
        ENV["Environment<br/>Values & Config"]
        MOD["View Modifiers<br/>Customization"]
    end

    %% Core Framework Layer  
    subgraph CORE [" Core Framework "]
        direction TB
        API["CodeEditorAPI<br/>Main Protocol"]
        CEV["CodeEditorView<br/>Text Engine Core"]
        CCV["ContainerView<br/>Layout Manager"]
        UES["Event System<br/>Coordination Hub"]
        AC["ActorCoordinator<br/>Concurrency"]
    end

    %% Business Services Layer
    subgraph SERVICES [" Business Logic Services "]
        direction TB
        BLS["Service Registry<br/>Dependency Injection"]
        subgraph SRVS [" Core Services "]
            TES["Text Editing<br/>Operations"]
            LDS["Language<br/>Detection"] 
            SHS["Syntax<br/>Highlighting"]
            CMS["Code<br/>Completion"]
            MMS["Memory<br/>Monitoring"]
            PM["Plugin<br/>Manager"]
        end
    end

    %% Configuration System
    subgraph CONFIG [" Configuration System "]
        direction TB
        EC["Editor<br/>Configuration"]
        subgraph CFGS [" Config Modules "]
            DC["Display<br/>Settings"]
            LC["Layout<br/>Options"]
            BC["Behavior<br/>Rules"] 
            PC["Performance<br/>Tuning"]
            PLGC["Plugin<br/>Settings"]
        end
    end

    %% Platform Abstraction Layer
    subgraph PLATFORM [" Platform Abstraction "]
        direction TB
        PAB["Platform<br/>Capabilities"]
        subgraph PLATS [" Platform Types "]
            PV["Platform<br/>Views"]
            PF["Platform<br/>Fonts"]
            PCL["Platform<br/>Colors"]
            CPC["Cross-Platform<br/>Coordinator"]
        end
    end

    %% Feature Components
    subgraph FEATURES [" Feature Components "]
        direction TB
        subgraph UI_FEAT [" UI Features "]
            GUT["Line Numbers<br/>& Gutter"]
            MM["Code<br/>Minimap"]
        end
        subgraph EDIT_FEAT [" Editing Features "]
            BRA["Bracket<br/>Matching"]
            FOLD["Code<br/>Folding"]
            IND["Smart<br/>Indentation"]
            ANN["Code<br/>Annotations"]
        end
    end

    %% Language Support System
    subgraph LANG [" Language Support "]
        direction TB
        LP["Language Provider<br/>Framework"]
        subgraph LANG_COMP [" Language Components "]
            SHL["Syntax<br/>Highlighters"]
            CP["Completion<br/>Providers"] 
            TOK["Language<br/>Tokenizers"]
        end
    end

    %% External Integrations
    subgraph EXTERNAL [" External Integrations "]
        direction TB
        LSP["LSP Client<br/>Language Servers"]
        PLG["Plugin System<br/>Extensibility"]
        SS["SwiftSyntax<br/>Swift AST"]
        subgraph PLUGINS [" Plugin Architecture "]
            PAPI["Plugin API<br/>Stable Interface"]
            PCTX["Plugin Context<br/>Controlled Access"]
            PEVT["Plugin Events<br/>Communication"]
        end
    end

    %% Main Architecture Flow
    SUI -.-> CORE
    CORE --> SERVICES
    SERVICES --> CONFIG
    CORE --> PLATFORM
    
    %% Detailed Connections
    SE --> API
    ENV --> EC
    MOD --> EC
    
    API --> CEV
    CEV --> CCV
    CEV --> UES
    CEV --> AC
    
    UES --> BLS
    BLS --> SRVS
    AC --> SRVS
    
    EC --> CFGS
    EC --> AC
    EC --> UES
    PAB --> PLATS
    
    CCV --> UI_FEAT
    CEV --> EDIT_FEAT
    
    SHS --> LP
    LP --> LANG_COMP
    
    CMS --> LSP
    SHL --> SS
    PM --> PLG
    PLG --> PLUGINS
    PAPI --> PCTX
    PCTX --> BLS
    PEVT --> UES
    
    %% Styling - Light/Dark mode compatible colors  
    classDef swiftui fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef core fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef service fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef config fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef platform fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef feature fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef lang fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef external fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    
    %% Apply styling to components
    class SE swiftui
    class ENV swiftui
    class MOD swiftui
    class API core
    class CEV core
    class CCV core
    class UES core
    class AC core
    class BLS service
    class TES service
    class LDS service
    class SHS service
    class CMS service
    class MMS service
    class PM service
    class EC config
    class DC config
    class LC config
    class BC config
    class PC config
    class PLGC config
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
    class PAPI external
    class PCTX external
    class PEVT external
```

## Key Architectural Principles

1. **Layered Architecture**: Clear separation between UI (SwiftUI), Core logic, Services, and Platform abstractions
2. **Protocol-Oriented**: Core functionality defined through protocols (CodeEditorAPI)
3. **Service-Based**: Business logic encapsulated in services managed by a central registry
4. **Dependency Injection**: No singletons - all dependencies injected via configuration
5. **Platform Agnostic**: Platform-specific code isolated in abstraction layer
6. **Event-Driven**: Unified event system for decoupled communication
7. **Configurable**: Comprehensive configuration system with environment integration
8. **Extensible**: Plugin system with stable API and controlled access
9. **Concurrent**: ActorCoordinator manages safe concurrent operations
10. **Memory Efficient**: Active memory monitoring and iOS-specific optimizations