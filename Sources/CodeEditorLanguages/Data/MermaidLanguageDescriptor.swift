import Foundation

extension LanguageDescriptor {
    // ── Mermaid ────────────────────────────────────────────────────
    static let mermaidDescriptor = Self(
            language: .mermaid,
            usesRegexHighlighter: true,
            lineComment: "%%",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "`"],
            highlightingRules: [
                // First-line diagram-type keyword (flowchart, sequenceDiagram, …)
                .init(
                    #"^\s*(?:flowchart-v2|flowchart-elk|flowchart|graph|sequenceDiagram|"# +
                    #"classDiagram-v2|classDiagram|stateDiagram-v2|stateDiagram|erDiagram|"# +
                    #"gantt|pie|journey|gitGraph|requirementDiagram|requirement|"# +
                    #"sankey-beta|sankey|mindmap|timeline|"# +
                    #"C4Context|C4Container|C4Component|C4Dynamic|C4Deployment|"# +
                    #"quadrantChart|xychart-beta|block-beta|packet-beta|kanban|"# +
                    #"zenuml|architecture|info|eventmodeling|radar-beta|"# +
                    #"treemap-beta|treemap|venn-beta|ishikawa-beta|ishikawa|"# +
                    #"treeView-beta|wardley-beta)\b"#,
                    .type,
                    priority: 10
                ),
                // <<…>> annotations
                .init(#"<<[^>]+>>"#, .property, priority: 9),
                // Edge / transition arrows (-->, ==>, -.->, o--, x==>, …)
                .init(
                    #"--+\>|--+x|--+[)o]|==+\>|[ox]\-{2,}>|[ox]=+>|-\.-+>|"# +
                    #"-->>|->>|[ox]\-+|\-{3,}|={3,}|\.\-\.|\.\.\>"#,
                    .operator,
                    priority: 8
                )
            ],
            keywords: [
                "title", "accTitle", "accDescr", "accDescription",
                "direction", "TB", "TD", "BT", "RL", "LR",
                "subgraph", "end",
                "classDef", "class", "style", "linkStyle",
                "click", "call", "href", "callback",
                "_self", "_blank", "_parent", "_top",
                "interpolate",
                "section", "dateFormat", "axisFormat", "todayMarker",
                "excludes", "inclusiveEndDates",
                "participant", "actor", "as",
                "Note", "note", "left of", "right of", "over",
                "activate", "deactivate", "autonumber",
                "loop", "alt", "else", "opt", "par", "and", "rect",
                "state", "hide empty description",
                "commit", "branch", "merge", "checkout", "reset",
                "cherry-pick",
                "showInfo", "showData",
                "link", "links", "properties",
                "option", "NORMAL", "REVERSE", "HIGHLIGHT",
                "requirement", "functionalRequirement",
                "interfaceRequirement", "performanceRequirement",
                "physicalRequirement", "designConstraint",
                "element",
                "rf", "resetframe", "tf", "timeframe",
                "data", "gwt"
            ],
            types: [
                "Person", "Person_Ext",
                "System", "System_Ext", "SystemDb", "SystemDb_Ext",
                "SystemQueue", "SystemQueue_Ext",
                "Container", "Container_Ext", "ContainerDb", "ContainerDb_Ext",
                "ContainerQueue", "ContainerQueue_Ext",
                "Component", "Component_Ext", "ComponentDb", "ComponentDb_Ext",
                "ComponentQueue", "ComponentQueue_Ext",
                "Boundary", "Enterprise_Boundary", "System_Boundary",
                "Container_Boundary",
                "Node", "Node_L", "Node_R", "Deployment_Node",
                "Rel", "BiRel",
                "Rel_Up", "Rel_Down", "Rel_Left", "Rel_Right", "Rel_Back",
                "RelIndex"
            ],
            functions: [],
            literals: [],
            triggerCharacters: [" "],
            snippets: [],
            memberCompletions: nil,
            commonModules: []
        )
}
