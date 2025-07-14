import Foundation

// MARK: - YAML Completion Data

/// Static data constants for YAML completion provider
public enum YAMLCompletionData {
    // MARK: - YAML Keywords
    
    static let keywords = ["true", "false", "null", "yes", "no", "on", "off"]
    
    // MARK: - Special Symbols
    
    static let specialSymbols = ["&", "*", "<<"]
    
    // MARK: - GitHub Actions Keys
    
    static let githubActionsKeys = [
        "name", "on", "env", "defaults", "concurrency", "jobs", "permissions",
        "runs-on", "needs", "if", "steps", "uses", "with", "run", "shell",
        "working-directory", "continue-on-error", "timeout-minutes", "strategy",
        "matrix", "fail-fast", "max-parallel", "container", "services", "outputs",
        "outcome", "outputs", "environment", "secrets", "id", "uses", "with"
    ]
    
    // MARK: - Docker Compose Keys
    
    static let dockerComposeKeys = [
        "version", "services", "networks", "volumes", "configs", "secrets",
        "image", "build", "command", "entrypoint", "container_name", "depends_on",
        "deploy", "environment", "expose", "external_links", "extra_hosts",
        "healthcheck", "labels", "links", "logging", "network_mode", "networks",
        "pid", "ports", "restart", "security_opt", "stop_grace_period", "stop_signal",
        "sysctls", "ulimits", "userns_mode", "volumes", "working_dir", "context",
        "dockerfile", "args", "cache_from", "labels", "shm_size", "target"
    ]
    
    // MARK: - Kubernetes Keys
    
    static let kubernetesKeys = [
        "apiVersion", "kind", "metadata", "spec", "status", "name", "namespace",
        "labels", "annotations", "selector", "template", "replicas", "containers",
        "image", "ports", "env", "volumeMounts", "volumes", "resources", "limits",
        "requests", "livenessProbe", "readinessProbe", "startupProbe", "command",
        "args", "workingDir", "envFrom", "imagePullPolicy", "lifecycle",
        "securityContext", "stdin", "stdinOnce", "targetPort", "protocol",
        "type", "clusterIP", "loadBalancerIP", "externalIPs", "sessionAffinity"
    ]
    
    // MARK: - Ansible Keys
    
    static let ansibleKeys = [
        "hosts", "tasks", "handlers", "vars", "vars_files", "roles", "include",
        "import_playbook", "pre_tasks", "post_tasks", "name", "become", "become_user",
        "become_method", "check_mode", "diff", "any_errors_fatal", "force_handlers",
        "gather_facts", "gather_subset", "gather_timeout", "ignore_errors",
        "ignore_unreachable", "max_fail_percentage", "order", "remote_user",
        "run_once", "serial", "strategy", "tags", "throttle", "timeout", "vars_prompt",
        "when", "with_items", "with_list", "with_dict", "loop", "register", "delegate_to",
        "local_action", "notify", "changed_when", "failed_when", "until", "retries", "delay"
    ]
    
    // MARK: - CircleCI Keys
    
    static let circleciKeys = [
        "version", "orbs", "commands", "executors", "jobs", "workflows", "triggers",
        "docker", "machine", "macos", "windows", "resource_class", "working_directory",
        "parallelism", "environment", "branches", "tags", "steps", "run", "checkout",
        "setup_remote_docker", "save_cache", "restore_cache", "deploy", "store_artifacts",
        "store_test_results", "persist_to_workspace", "attach_workspace", "add_ssh_keys",
        "when", "unless", "condition", "requires", "context", "filters", "only", "ignore",
        "schedule", "cron", "parameters", "pipeline", "setup", "path", "key", "keys",
        "paths", "root", "destination", "command", "name", "no_output_timeout", "background"
    ]
    
    // MARK: - Snippet Templates
    
    static let snippets: [SnippetTemplate] = [
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
    image: ${3:nginx:alpine}
    ports:
      - "${4:80}:${5:80}"
    volumes:
      - ${6:./data}:${7:/usr/share/nginx/html}
""",
            description: "Docker Compose service"
        ),
        SnippetTemplate(
            label: "kubernetes-deployment",
            insertText: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${1:app}
  namespace: ${2:default}
spec:
  replicas: ${3:3}
  selector:
    matchLabels:
      app: ${1:app}
  template:
    metadata:
      labels:
        app: ${1:app}
    spec:
      containers:
      - name: ${1:app}
        image: ${4:nginx:1.21}
        ports:
        - containerPort: ${5:80}
""",
            description: "Kubernetes Deployment"
        ),
        SnippetTemplate(
            label: "kubernetes-service",
            insertText: """
apiVersion: v1
kind: Service
metadata:
  name: ${1:app-service}
  namespace: ${2:default}
spec:
  selector:
    app: ${3:app}
  ports:
    - protocol: TCP
      port: ${4:80}
      targetPort: ${5:80}
  type: ${6|LoadBalancer,ClusterIP,NodePort|}
""",
            description: "Kubernetes Service"
        ),
        SnippetTemplate(
            label: "ansible-playbook",
            insertText: """
---
- name: ${1:Configure servers}
  hosts: ${2:all}
  become: ${3:yes}
  
  tasks:
    - name: ${4:Ensure nginx is installed}
      ${5:package}:
        name: ${6:nginx}
        state: ${7:present}
""",
            description: "Ansible playbook"
        ),
        SnippetTemplate(
            label: "circleci-config",
            insertText: """
version: 2.1

jobs:
  ${1:build}:
    docker:
      - image: ${2:cimg/node:18.0}
    steps:
      - checkout
      - run:
          name: ${3:Install dependencies}
          command: ${4:npm install}
      - run:
          name: ${5:Run tests}
          command: ${6:npm test}

workflows:
  ${7:main}:
    jobs:
      - ${1:build}
""",
            description: "CircleCI configuration"
        ),
        SnippetTemplate(
            label: "key-value",
            insertText: "${1:key}: ${2:value}",
            description: "Key-value pair"
        ),
        SnippetTemplate(
            label: "array",
            insertText: """
${1:items}:
  - ${2:item1}
  - ${3:item2}
  - ${4:item3}
""",
            description: "Array/List"
        ),
        SnippetTemplate(
            label: "object",
            insertText: """
${1:object}:
  ${2:property1}: ${3:value1}
  ${4:property2}: ${5:value2}
""",
            description: "Object/Map"
        ),
        SnippetTemplate(
            label: "anchor",
            insertText: "${1:item}: &${2:anchor} ${3:value}",
            description: "YAML anchor"
        ),
        SnippetTemplate(
            label: "alias",
            insertText: "${1:item}: *${2:anchor}",
            description: "YAML alias"
        ),
        SnippetTemplate(
            label: "merge",
            insertText: "<<: *${1:anchor}",
            description: "YAML merge"
        ),
        SnippetTemplate(
            label: "multiline-literal",
            insertText: """
${1:text}: |
  ${2:Line 1}
  ${3:Line 2}
  ${4:Line 3}
""",
            description: "Multiline literal"
        ),
        SnippetTemplate(
            label: "multiline-folded",
            insertText: """
${1:text}: >
  ${2:This text will be folded}
  ${3:into a single line with}
  ${4:spaces between the words.}
""",
            description: "Multiline folded"
        ),
        SnippetTemplate(
            label: "env-var",
            insertText: "${1:VAR_NAME}: \\${${2:ENV_VAR}:-${3:default}}",
            description: "Environment variable with default"
        )
    ]
    
    // MARK: - Common YAML File Types
    
    static let yamlFileTypes = [
        ".yml", ".yaml", "docker-compose.yml", "docker-compose.yaml",
        ".gitlab-ci.yml", ".travis.yml", "ansible.cfg", "playbook.yml",
        "values.yaml", "Chart.yaml", "config.yml", "config.yaml",
        "application.yml", "application.yaml", "swagger.yml", "swagger.yaml",
        "openapi.yml", "openapi.yaml"
    ]
    
    // MARK: - Common Data Types
    
    static let dataTypes = ["string", "number", "integer", "boolean", "array", "object", "null"]
}
