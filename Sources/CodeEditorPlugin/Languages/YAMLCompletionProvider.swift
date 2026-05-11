import Foundation

// MARK: - YAML Completion Provider

/// Built-in completion provider for YAML language
@MainActor
final class YAMLCompletionProvider: BaseCompletionProvider {
    // Reference to static data from YAMLCompletionData
    private let specialSymbols = YAMLCompletionData.specialSymbols
    private let githubActionsKeys = YAMLCompletionData.githubActionsKeys
    private let dockerComposeKeys = YAMLCompletionData.dockerComposeKeys
    private let kubernetesKeys = YAMLCompletionData.kubernetesKeys
    private let ansibleKeys = YAMLCompletionData.ansibleKeys
    private let circleciKeys = YAMLCompletionData.circleciKeys

    // MARK: - Overridden Properties

    override var keywords: [String] {
        YAMLCompletionData.keywords
    }

    override var snippets: [SnippetTemplate] {
        YAMLCompletionData.snippets
    }

    // MARK: - Initialization

    init() {
        super.init(
            id: "yaml-builtin",
            supportedLanguages: [.yaml],
            triggerCharacters: [":", "-", " ", ".", "$", "{"],
            supportsSnippets: true
        )
    }

    // MARK: - Override BaseCompletionProvider Methods

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let yamlAnalysisResult = analyzeYAMLContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch yamlAnalysisResult.type {
        case .key:
            items.append(contentsOf: createKeyCompletions(for: yamlAnalysisResult.fileType, parentKey: yamlAnalysisResult.parentKey, filter: yamlAnalysisResult.filter))

        case .value:
            items.append(contentsOf: createValueCompletions(for: yamlAnalysisResult.key, fileType: yamlAnalysisResult.fileType, filter: yamlAnalysisResult.filter))

        case .listItem:
            items.append(contentsOf: createListItemCompletions(filter: yamlAnalysisResult.filter))

        case .reference:
            items.append(contentsOf: createReferenceCompletions(filter: yamlAnalysisResult.filter))

        case .general:
            items.append(contentsOf: createYAMLKeywordCompletions(filter: yamlAnalysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createYAMLSnippetCompletions(filter: yamlAnalysisResult.filter))
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }

    override func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-*&")).inverted)
        return components.last ?? ""
    }

    // MARK: - YAML-Specific Context Analysis

    private func analyzeYAMLContext(_ context: CompletionContextModel) -> YAMLContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = context.textBeforeCursor
        let fileType = detectFileType(from: context.text)

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check if we're at the start of a list item
        if lineText.hasPrefix("-") && lineText.count > 1 {
            return YAMLContextAnalysisResult(type: .listItem, filter: filter, fileType: fileType)
        }

        // Check if we're in a reference context (& or *)
        if beforeCursor.hasSuffix("&") || beforeCursor.hasSuffix("*") || filter.hasPrefix("*") {
            return YAMLContextAnalysisResult(type: .reference, filter: filter, fileType: fileType)
        }

        // Check if we're in a key position
        if isInKeyPosition(lineText, beforeCursor) {
            let parentKey = findParentKey(in: beforeCursor)
            return YAMLContextAnalysisResult(type: .key, filter: filter, fileType: fileType, parentKey: parentKey)
        }

        // Check if we're in a value position
        if let currentKey = getCurrentKey(from: lineText) {
            return YAMLContextAnalysisResult(type: .value, filter: filter, fileType: fileType, key: currentKey)
        }

        return YAMLContextAnalysisResult(type: .general, filter: filter, fileType: fileType)
    }

    private func detectFileType(from text: String) -> YAMLFileType {
        // GitHub Actions
        if text.contains("on:") && text.contains("jobs:") && text.contains("steps:") {
            return .githubActions
        }

        // Docker Compose
        if text.contains("version:") && text.contains("services:") {
            return .dockerCompose
        }

        // Kubernetes
        if text.contains("apiVersion:") && text.contains("kind:") {
            return .kubernetes
        }

        // Ansible
        if text.contains("hosts:") || text.contains("tasks:") || text.contains("- name:") {
            return .ansible
        }

        // CircleCI
        if text.contains("version:") && (text.contains("orbs:") || text.contains("workflows:")) {
            return .circleci
        }

        return .generic
    }

    private func isInKeyPosition(_ lineText: String, _: String) -> Bool {
        // Check indentation to determine if we're at a key position
        let trimmedLine = lineText.trimmingCharacters(in: .whitespaces)

        // Empty line or just started typing
        if trimmedLine.isEmpty || !trimmedLine.contains(":") {
            return true
        }

        // After a list item dash
        if trimmedLine.hasPrefix("- ") && !trimmedLine.dropFirst(2).contains(":") {
            return true
        }

        return false
    }

    private func getCurrentKey(from lineText: String) -> String? {
        // Extract key from current line
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
            return key.hasPrefix("- ") ? String(key.dropFirst(2)) : key
        }
        return nil
    }

    private func findParentKey(in text: String) -> String? {
        // Find parent key based on indentation
        let lines = text.components(separatedBy: .newlines)
        var currentIndent = Int.max

        // Find current line's indentation
        if let lastLine = lines.last {
            currentIndent = lastLine.prefix { $0 == " " }.count
        }

        // Search backwards for a line with less indentation that has a key
        for line in lines.reversed() {
            let indent = line.prefix { $0 == " " }.count
            if indent < currentIndent {
                if let key = getCurrentKey(from: line) {
                    return key
                }
            }
        }

        return nil
    }

    // MARK: - Completion Creation Methods

    private func createKeyCompletions(for fileType: YAMLFileType, parentKey: String?, filter: String) -> [CompletionItemModel] {
        var keys: [String] = []

        switch fileType {
        case .githubActions:
            if parentKey == "on" {
                keys = ["push", "pull_request", "workflow_dispatch", "schedule", "release", "issues", "issue_comment"]
            } else if parentKey == "steps" {
                keys = ["name", "uses", "run", "with", "if", "id", "continue-on-error", "timeout-minutes"]
            } else {
                keys = githubActionsKeys
            }

        case .dockerCompose:
            if parentKey == "services" {
                keys = dockerComposeKeys.filter { !["version", "services", "networks", "volumes"].contains($0) }
            } else {
                keys = dockerComposeKeys
            }

        case .kubernetes:
            if parentKey == "spec" {
                keys = ["replicas", "selector", "template", "containers", "ports", "volumes"]
            } else if parentKey == "metadata" {
                keys = ["name", "namespace", "labels", "annotations"]
            } else {
                keys = kubernetesKeys
            }

        case .ansible:
            if parentKey == "tasks" || parentKey == "handlers" {
                keys = ansibleKeys.filter { !["hosts", "tasks", "handlers", "vars", "roles"].contains($0) }
            } else {
                keys = ansibleKeys
            }

        case .circleci:
            if parentKey == "steps" {
                keys = ["run", "checkout", "save_cache", "restore_cache", "store_artifacts", "store_test_results"]
            } else {
                keys = circleciKeys
            }

        case .generic:
            // No specific keys for generic YAML
            break
        }

        return keys
            .filter { key in
                filter.isEmpty || key.localizedCaseInsensitiveContains(filter)
            }
            .map { key in
                CompletionItemModel(
                    label: key,
                    insertText: "\(key): ",
                    kind: .property,
                    detail: "YAML key",
                    priority: 80
                )
            }
    }

    private func createValueCompletions(for key: String?, fileType: YAMLFileType, filter: String) -> [CompletionItemModel] {
        guard let key else { return [] }

        var items: [CompletionItemModel] = []

        // Add boolean values for common boolean keys
        let booleanKeys = ["continue-on-error", "fail-fast", "required", "become", "gather_facts", "ignore_errors", "run_once"]
        if booleanKeys.contains(key) {
            items.append(contentsOf: createYAMLKeywordCompletions(filter: filter).filter { ["true", "false", "yes", "no"].contains($0.label) })
        }

        // Add specific values based on key and file type
        switch fileType {
        case .githubActions:
            if key == "runs-on" {
                items.append(contentsOf: createRunsOnCompletions(filter: filter))
            } else if key == "shell" {
                items.append(contentsOf: createShellCompletions(filter: filter))
            }

        case .dockerCompose:
            if key == "restart" {
                items.append(contentsOf: createRestartPolicyCompletions(filter: filter))
            }

        case .kubernetes:
            if key == "kind" {
                items.append(contentsOf: createKubernetesKindCompletions(filter: filter))
            } else if key == "imagePullPolicy" {
                items.append(contentsOf: createImagePullPolicyCompletions(filter: filter))
            }

        default:
            break
        }

        // Always add keywords
        items.append(contentsOf: createYAMLKeywordCompletions(filter: filter))

        return items
    }

    private func createListItemCompletions(filter _: String) -> [CompletionItemModel] {
        // Context-aware list item suggestions
        [
            CompletionItemModel(
                label: "- ",
                insertText: "- $0",
                kind: .snippet,
                detail: "List item",
                priority: 90
            )
        ]
    }

    private func createReferenceCompletions(filter: String) -> [CompletionItemModel] {
        var items: [CompletionItemModel] = []

        // Anchor
        if filter.hasPrefix("&") || filter.isEmpty {
            items.append(CompletionItemModel(
                label: "&anchor",
                insertText: "&${1:anchor_name}",
                kind: .reference,
                detail: "YAML anchor",
                priority: 85
            ))
        }

        // Alias
        if filter.hasPrefix("*") || filter.isEmpty {
            items.append(CompletionItemModel(
                label: "*alias",
                insertText: "*${1:anchor_name}",
                kind: .reference,
                detail: "YAML alias",
                priority: 85
            ))
        }

        // Merge
        items.append(CompletionItemModel(
            label: "<<",
            insertText: "<<: *${1:anchor_name}",
            kind: .operator,
            detail: "YAML merge",
            priority: 80
        ))

        return items
    }

    private func createYAMLKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "YAML value",
                    priority: 70
                )
            }
    }

    private func createRunsOnCompletions(filter: String) -> [CompletionItemModel] {
        let runners = [
            "ubuntu-latest", "ubuntu-22.04", "ubuntu-20.04",
            "windows-latest", "windows-2022", "windows-2019",
            "macos-latest", "macos-13", "macos-12", "macos-11"
        ]

        return runners
            .filter { runner in
                filter.isEmpty || runner.localizedCaseInsensitiveContains(filter)
            }
            .map { runner in
                CompletionItemModel(
                    label: runner,
                    insertText: runner,
                    kind: .value,
                    detail: "GitHub runner",
                    priority: 85
                )
            }
    }

    private func createShellCompletions(filter: String) -> [CompletionItemModel] {
        let shells = ["bash", "pwsh", "python", "sh", "cmd", "powershell"]

        return shells
            .filter { shell in
                filter.isEmpty || shell.localizedCaseInsensitiveContains(filter)
            }
            .map { shell in
                CompletionItemModel(
                    label: shell,
                    insertText: shell,
                    kind: .value,
                    detail: "Shell type",
                    priority: 85
                )
            }
    }

    private func createRestartPolicyCompletions(filter: String) -> [CompletionItemModel] {
        let policies = ["no", "always", "on-failure", "unless-stopped"]

        return policies
            .filter { policy in
                filter.isEmpty || policy.localizedCaseInsensitiveContains(filter)
            }
            .map { policy in
                CompletionItemModel(
                    label: policy,
                    insertText: policy,
                    kind: .value,
                    detail: "Restart policy",
                    priority: 85
                )
            }
    }

    private func createKubernetesKindCompletions(filter: String) -> [CompletionItemModel] {
        let kinds = [
            "Pod", "Service", "Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob",
            "ConfigMap", "Secret", "Ingress", "PersistentVolume", "PersistentVolumeClaim",
            "Namespace", "ServiceAccount", "Role", "RoleBinding", "ClusterRole", "ClusterRoleBinding"
        ]

        return kinds
            .filter { kind in
                filter.isEmpty || kind.localizedCaseInsensitiveContains(filter)
            }
            .map { kind in
                CompletionItemModel(
                    label: kind,
                    insertText: kind,
                    kind: .class,
                    detail: "Kubernetes resource",
                    priority: 85
                )
            }
    }

    private func createImagePullPolicyCompletions(filter: String) -> [CompletionItemModel] {
        let policies = ["Always", "Never", "IfNotPresent"]

        return policies
            .filter { policy in
                filter.isEmpty || policy.localizedCaseInsensitiveContains(filter)
            }
            .map { policy in
                CompletionItemModel(
                    label: policy,
                    insertText: policy,
                    kind: .value,
                    detail: "Image pull policy",
                    priority: 85
                )
            }
    }

    private func createYAMLSnippetCompletions(filter: String) -> [CompletionItemModel] {
        snippets
            .filter { snippet in
                filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
            }
            .map { snippet in
                CompletionItemModel(
                    label: snippet.label,
                    insertText: snippet.insertText,
                    kind: .snippet,
                    detail: snippet.description,
                    priority: 90,
                    snippetSupport: true
                )
            }
    }
}

// MARK: - Supporting Types

private struct YAMLContextAnalysisResult {
    enum CompletionType {
        case key
        case value
        case listItem
        case reference
        case general
    }

    let type: CompletionType
    let filter: String
    let fileType: YAMLFileType
    let key: String?
    let parentKey: String?

    init(type: CompletionType, filter: String, fileType: YAMLFileType, key: String? = nil, parentKey: String? = nil) {
        self.type = type
        self.filter = filter
        self.fileType = fileType
        self.key = key
        self.parentKey = parentKey
    }
}

private enum YAMLFileType {
    case githubActions
    case dockerCompose
    case kubernetes
    case ansible
    case circleci
    case generic
}
