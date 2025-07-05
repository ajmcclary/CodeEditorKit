import Foundation

// MARK: - YAML Completion Provider

/// Built-in completion provider for YAML language
@MainActor
public final class YAMLCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "yaml-builtin"
    public let supportedLanguages: [Language] = [.yaml]
    public let triggerCharacters = [":", "-", " ", ".", "$", "{"]
    public let supportsSnippets = true
    
    // YAML keywords and special values
    private let keywords = ["true", "false", "null", "yes", "no", "on", "off"]
    
    // Common YAML anchors and aliases
    private let specialSymbols = ["&", "*", "<<"]
    
    // GitHub Actions workflow keys
    private let githubActionsKeys = [
        "name", "on", "env", "defaults", "concurrency", "jobs", "permissions",
        "runs-on", "needs", "if", "steps", "uses", "with", "run", "shell",
        "working-directory", "continue-on-error", "timeout-minutes", "strategy",
        "matrix", "fail-fast", "max-parallel", "container", "services", "outputs",
        "outcome", "outputs", "environment", "secrets", "id", "uses", "with"
    ]
    
    // Docker Compose keys
    private let dockerComposeKeys = [
        "version", "services", "networks", "volumes", "configs", "secrets",
        "image", "build", "command", "entrypoint", "container_name", "depends_on",
        "deploy", "environment", "expose", "external_links", "extra_hosts",
        "healthcheck", "labels", "links", "logging", "network_mode", "networks",
        "pid", "ports", "restart", "security_opt", "stop_grace_period", "stop_signal",
        "sysctls", "ulimits", "userns_mode", "volumes", "working_dir", "context",
        "dockerfile", "args", "cache_from", "labels", "shm_size", "target"
    ]
    
    // Kubernetes resource keys
    private let kubernetesKeys = [
        "apiVersion", "kind", "metadata", "spec", "status", "name", "namespace",
        "labels", "annotations", "selector", "template", "replicas", "containers",
        "image", "ports", "env", "volumeMounts", "volumes", "resources", "limits",
        "requests", "livenessProbe", "readinessProbe", "startupProbe", "command",
        "args", "workingDir", "envFrom", "imagePullPolicy", "lifecycle",
        "securityContext", "stdin", "stdinOnce", "targetPort", "protocol",
        "type", "clusterIP", "loadBalancerIP", "externalIPs", "sessionAffinity"
    ]
    
    // Ansible playbook keys
    private let ansibleKeys = [
        "hosts", "tasks", "handlers", "vars", "vars_files", "roles", "include",
        "import_playbook", "pre_tasks", "post_tasks", "name", "become", "become_user",
        "become_method", "check_mode", "diff", "any_errors_fatal", "force_handlers",
        "gather_facts", "gather_subset", "gather_timeout", "ignore_errors",
        "ignore_unreachable", "max_fail_percentage", "order", "remote_user",
        "run_once", "serial", "strategy", "tags", "throttle", "timeout", "vars_prompt",
        "when", "with_items", "with_list", "with_dict", "loop", "register", "delegate_to",
        "local_action", "notify", "changed_when", "failed_when", "until", "retries", "delay"
    ]
    
    // CircleCI config keys
    private let circleciKeys = [
        "version", "orbs", "commands", "executors", "jobs", "workflows", "triggers",
        "docker", "machine", "macos", "windows", "resource_class", "working_directory",
        "parallelism", "environment", "branches", "tags", "steps", "run", "checkout",
        "setup_remote_docker", "save_cache", "restore_cache", "deploy", "store_artifacts",
        "store_test_results", "persist_to_workspace", "attach_workspace", "add_ssh_keys",
        "when", "unless", "condition", "requires", "context", "filters", "only", "ignore",
        "schedule", "cron", "parameters", "pipeline", "setup", "path", "key", "keys",
        "paths", "root", "destination", "command", "name", "no_output_timeout", "background"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "github-workflow",
            insertText: """
name: ${1:CI}

on:
  push:
    branches: [ ${2:main} ]
  pull_request:
    branches: [ ${3:main} ]

jobs:
  ${4:build}:
    runs-on: ${5:ubuntu-latest}
    
    steps:
    - uses: actions/checkout@v3
    - name: ${6:Build}
      run: ${7:echo "Building..."}
""",
            description: "GitHub Actions workflow"
        ),
        SnippetTemplate(
            label: "docker-compose",
            insertText: """
version: '${1:3.8}'

services:
  ${2:app}:
    image: ${3:node:alpine}
    container_name: ${4:my-app}
    ports:
      - "${5:3000}:${6:3000}"
    environment:
      - ${7:NODE_ENV=production}
    volumes:
      - ${8:./app:/app}
    command: ${9:npm start}
""",
            description: "Docker Compose service"
        ),
        SnippetTemplate(
            label: "kubernetes-deployment",
            insertText: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${1:app-deployment}
  labels:
    app: ${2:app}
spec:
  replicas: ${3:3}
  selector:
    matchLabels:
      app: ${2:app}
  template:
    metadata:
      labels:
        app: ${2:app}
    spec:
      containers:
      - name: ${4:app}
        image: ${5:nginx:latest}
        ports:
        - containerPort: ${6:80}
""",
            description: "Kubernetes Deployment"
        ),
        SnippetTemplate(
            label: "ansible-playbook",
            insertText: """
---
- name: ${1:Playbook Name}
  hosts: ${2:all}
  become: ${3:yes}
  
  vars:
    ${4:variable_name}: ${5:value}
  
  tasks:
    - name: ${6:Task name}
      ${7:debug}:
        msg: "${8:Hello World}"
""",
            description: "Ansible Playbook"
        ),
        SnippetTemplate(
            label: "circleci-config",
            insertText: """
version: 2.1

orbs:
  ${1:node}: circleci/${1:node}@5.0.0

jobs:
  ${2:build}:
    docker:
      - image: cimg/${3:node}:${4:16.0}
    steps:
      - checkout
      - run:
          name: ${5:Install Dependencies}
          command: ${6:npm install}
      - run:
          name: ${7:Run Tests}
          command: ${8:npm test}

workflows:
  ${9:main}:
    jobs:
      - ${2:build}
""",
            description: "CircleCI Configuration"
        ),
        SnippetTemplate(
            label: "key-value",
            insertText: "${1:key}: ${2:value}",
            description: "Key-value pair"
        ),
        SnippetTemplate(
            label: "list-item",
            insertText: "- ${1:item}",
            description: "List item"
        ),
        SnippetTemplate(
            label: "array",
            insertText: """
${1:key}:
  - ${2:item1}
  - ${3:item2}
""",
            description: "Array structure"
        ),
        SnippetTemplate(
            label: "object",
            insertText: """
${1:key}:
  ${2:nested_key}: ${3:value}
  ${4:another_key}: ${5:value}
""",
            description: "Object structure"
        )
    ]
    
    public init() {}
    
    // MARK: - CompletionProvider Implementation
    
    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()
        
        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeContext(context)
        var items: [CompletionItemModel] = []
        
        // Add appropriate completions based on context
        switch analysisResult.type {
        case .key:
            items.append(contentsOf: createKeyCompletions(for: analysisResult.fileType, parentKey: analysisResult.parentKey, filter: analysisResult.filter))
            
        case .value:
            items.append(contentsOf: createValueCompletions(for: analysisResult.key, fileType: analysisResult.fileType, filter: analysisResult.filter))
            
        case .listItem:
            items.append(contentsOf: createListItemCompletions(filter: analysisResult.filter))
            
        case .reference:
            items.append(contentsOf: createReferenceCompletions(filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
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
    
    // MARK: - Context Analysis
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        let fileType = detectFileType(from: context.text)
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check if we're at the start of a list item
        if lineText.hasPrefix("-") && lineText.count > 1 {
            return ContextAnalysisResult(type: .listItem, filter: filter, fileType: fileType)
        }
        
        // Check if we're in a reference context (& or *)
        if beforeCursor.hasSuffix("&") || beforeCursor.hasSuffix("*") || filter.hasPrefix("*") {
            return ContextAnalysisResult(type: .reference, filter: filter, fileType: fileType)
        }
        
        // Check if we're in a key position
        if isInKeyPosition(lineText, beforeCursor) {
            let parentKey = findParentKey(in: beforeCursor)
            return ContextAnalysisResult(type: .key, filter: filter, fileType: fileType, parentKey: parentKey)
        }
        
        // Check if we're in a value position
        if let currentKey = getCurrentKey(from: lineText) {
            return ContextAnalysisResult(type: .value, filter: filter, fileType: fileType, key: currentKey)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter, fileType: fileType)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-*&")).inverted)
        return components.last ?? ""
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
            items.append(contentsOf: createKeywordCompletions(filter: filter).filter { ["true", "false", "yes", "no"].contains($0.label) })
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
        items.append(contentsOf: createKeywordCompletions(filter: filter))
        
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
    
    private func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
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
    
    private func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
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

private struct ContextAnalysisResult {
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

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
