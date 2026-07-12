# Event System Flow Diagram

`EditorEventBus` is the single ordered publication point. Combine, the legacy publisher, weak handlers, and `NotificationCenter` are projections from that bus rather than independent sources.

```mermaid
flowchart LR
    SOURCES[Editor and Feature Events] --> PUBLISH[CodeEditorView.publishEvent]
    PUBLISH --> BUS[EditorEventBus]
    BUS --> ORDER[SequencedEditorEvent History]
    BUS --> STREAM[AsyncStream]
    BUS --> UNIFIED[UnifiedEventSystem Adapter]
    BUS --> LEGACY[EditorEventPublisher Adapter]
    BUS --> NOTIFY[NotificationCenterEventAdapter]

    UNIFIED --> COMBINE[Combine Publishers]
    UNIFIED --> HANDLERS[Filtered Weak Handlers]
    NOTIFY --> SELECTION[Legacy Selection Notification]
    LEGACY --> COMPAT[Legacy Event Streams]
```

All adapters observe the same sequence, so one editor action results in one canonical bus publication.
