import Foundation

// MARK: - Shell Completion Provider

/// Built-in completion provider for Shell/Bash language
@MainActor
final class ShellCompletionProvider: BaseCompletionProvider {
    // Shell-specific context (stored for use in completions method)
    private var shellContext = ShellContextAnalysisResult(type: .general, filter: "")

    // Shell built-in commands
    private let builtinCommands = [
        // Bash builtins
        "alias", "bg", "bind", "break", "builtin", "caller", "cd", "command",
        "compgen", "complete", "compopt", "continue", "declare", "dirs", "disown",
        "echo", "enable", "eval", "exec", "exit", "export", "fc", "fg", "getopts",
        "hash", "help", "history", "jobs", "kill", "let", "local", "logout",
        "mapfile", "popd", "printf", "pushd", "pwd", "read", "readonly", "return",
        "set", "shift", "shopt", "source", "suspend", "test", "times", "trap",
        "type", "typeset", "ulimit", "umask", "unalias", "unset", "wait",
        // Common shell keywords
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
        "until", "do", "done", "function", "select", "time", "in"
    ]

    // Common Unix/Linux commands
    private let systemCommands = [
        // File operations
        "ls", "cd", "pwd", "mkdir", "rmdir", "rm", "cp", "mv", "ln", "find",
        "locate", "which", "whereis", "file", "stat", "du", "df", "tree",
        "rsync", "scp", "sftp", "ftp", "wget", "curl", "tar", "gzip", "gunzip",
        "zip", "unzip", "7zip", "bzip2", "bunzip2", "xz", "unxz",
        // Text processing
        "cat", "less", "more", "head", "tail", "grep", "egrep", "fgrep",
        "sed", "awk", "cut", "sort", "uniq", "wc", "tr", "fold", "fmt",
        "column", "paste", "join", "comm", "diff", "patch", "cmp",
        // Process management
        "ps", "top", "htop", "jobs", "kill", "killall", "pkill", "pgrep",
        "nohup", "screen", "tmux", "bg", "fg", "disown", "wait",
        // System information
        "uname", "whoami", "who", "w", "id", "groups", "last", "lastlog",
        "uptime", "date", "cal", "timedatectl", "systemctl", "service",
        "mount", "umount", "lsblk", "fdisk", "free", "lscpu", "lsusb",
        "lspci", "lsmod", "dmesg", "journalctl", "hostname", "hostnamectl",
        // Network
        "ping", "traceroute", "netstat", "ss", "lsof", "iptables", "ip",
        "ifconfig", "route", "arp", "dig", "nslookup", "host", "nc", "netcat",
        "telnet", "ssh", "scp", "rsync", "ftp", "sftp",
        // Archives and compression
        "tar", "gzip", "gunzip", "bzip2", "bunzip2", "xz", "unxz", "compress",
        "uncompress", "zip", "unzip", "rar", "unrar", "7z",
        // Permissions and ownership
        "chmod", "chown", "chgrp", "umask", "su", "sudo", "passwd", "chage",
        "usermod", "useradd", "userdel", "groupadd", "groupdel", "groupmod",
        // Package management (various distros)
        "apt", "apt-get", "aptitude", "dpkg", "yum", "dnf", "rpm", "zypper",
        "pacman", "emerge", "portage", "brew", "port", "pkg", "snap", "flatpak",
        // Text editors
        "vim", "vi", "nano", "emacs", "ed", "joe", "gedit", "code", "subl",
        // Development tools
        "git", "svn", "hg", "make", "cmake", "gcc", "g++", "clang", "rustc",
        "go", "python", "python3", "node", "npm", "yarn", "pip", "pip3",
        "ruby", "gem", "bundle", "mvn", "gradle", "javac", "java",
        // System monitoring
        "iostat", "vmstat", "sar", "mpstat", "pidstat", "iotop", "nethogs",
        "iftop", "tcpdump", "wireshark", "strace", "ltrace", "gdb", "valgrind"
    ]

    // Common environment variables
    private let environmentVariables = [
        "$HOME", "$PATH", "$USER", "$PWD", "$OLDPWD", "$SHELL", "$TERM",
        "$EDITOR", "$VISUAL", "$PAGER", "$BROWSER", "$LANG", "$LC_ALL",
        "$TZ", "$TMPDIR", "$HOSTNAME", "$HOSTTYPE", "$OSTYPE", "$MACHTYPE",
        "$BASH", "$BASH_VERSION", "$BASHPID", "$PPID", "$UID", "$EUID",
        "$GROUPS", "$SHELLOPTS", "$BASHOPTS", "$PS1", "$PS2", "$PS3", "$PS4",
        "$IFS", "$RANDOM", "$SECONDS", "$LINENO", "$FUNCNAME", "$BASH_SOURCE",
        "$BASH_LINENO", "$BASH_SUBSHELL", "$BASH_EXECUTION_STRING",
        "$MAIL", "$MAILCHECK", "$MAILPATH", "$CDPATH", "$GLOBIGNORE",
        "$HISTFILE", "$HISTSIZE", "$HISTFILESIZE", "$HISTCONTROL", "$HISTIGNORE"
    ]

    // Common command-line options/flags
    private let commonOptions = [
        // Universal options
        "-h", "--help", "-v", "--version", "-V", "--verbose", "-q", "--quiet",
        "-f", "--force", "-i", "--interactive", "-n", "--dry-run", "-y", "--yes",
        // File listing options
        "-l", "-a", "-A", "-r", "-R", "-t", "-S", "-h", "-1", "--color",
        // Copy/move options
        "-r", "-R", "--recursive", "-p", "--preserve", "-u", "--update",
        "-b", "--backup", "-f", "--force", "-i", "--interactive", "-n", "--no-clobber",
        // Find options
        "-name", "-type", "-size", "-mtime", "-atime", "-ctime", "-exec",
        "-print", "-delete", "-maxdepth", "-mindepth", "-follow",
        // Grep options
        "-i", "--ignore-case", "-v", "--invert-match", "-r", "--recursive",
        "-n", "--line-number", "-c", "--count", "-l", "--files-with-matches",
        "-H", "--with-filename", "-o", "--only-matching", "-E", "--extended-regexp",
        // Process options
        "-e", "-f", "-u", "-p", "-t", "-o", "-k", "-9", "-TERM", "-KILL", "-HUP"
    ]

    // Shell operators and special characters
    private let operators = [
        "&&", "||", "|", "&", ";", "(", ")", "[", "]", "[[", "]]", "{", "}",
        "<", ">", "<<", ">>", "<&", ">&", "<>", "2>", "2>>", "2>&1", "&>",
        "$", "${", "$(", "`", "\"", "'", "\\", "*", "?", "~", "!"
    ]

    private let shellSnippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "if",
            insertText: """
if [[ ${1:condition} ]]; then
    ${2:# commands}
fi
""",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "ifelse",
            insertText: """
if [[ ${1:condition} ]]; then
    ${2:# if true}
else
    ${3:# if false}
fi
""",
            description: "If-else statement"
        ),
        SnippetTemplate(
            label: "elif",
            insertText: """
if [[ ${1:condition1} ]]; then
    ${2:# first condition}
elif [[ ${3:condition2} ]]; then
    ${4:# second condition}
else
    ${5:# default}
fi
""",
            description: "If-elif-else statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: """
for ${1:item} in ${2:list}; do
    ${3:# commands}
done
""",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: """
while [[ ${1:condition} ]]; do
    ${2:# commands}
done
""",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "until",
            insertText: """
until [[ ${1:condition} ]]; do
    ${2:# commands}
done
""",
            description: "Until loop"
        ),
        SnippetTemplate(
            label: "case",
            insertText: """
case ${1:variable} in
    ${2:pattern1})
        ${3:# commands}
        ;;
    ${4:pattern2})
        ${5:# commands}
        ;;
    *)
        ${6:# default}
        ;;
esac
""",
            description: "Case statement"
        ),
        SnippetTemplate(
            label: "function",
            insertText: """
${1:function_name}() {
    ${2:# function body}
}
""",
            description: "Function definition"
        ),
        SnippetTemplate(
            label: "function-full",
            insertText: """
function ${1:function_name}() {
    local ${2:var}="${3:value}"
    ${4:# function body}
    return ${5:0}
}
""",
            description: "Full function definition"
        ),
        SnippetTemplate(
            label: "array",
            insertText: """
${1:array_name}=(${2:"item1" "item2" "item3"})
for ${3:item} in "\\${${1:array_name}[@]}"; do
    ${4:# process item}
done
""",
            description: "Array definition and iteration"
        ),
        SnippetTemplate(
            label: "read",
            insertText: """
read -p "${1:Enter value: }" ${2:variable}
""",
            description: "Read user input"
        ),
        SnippetTemplate(
            label: "trap",
            insertText: """
trap '${1:cleanup_function}' ${2:EXIT}
""",
            description: "Trap signal"
        ),
        SnippetTemplate(
            label: "heredoc",
            insertText: """
cat << ${1:EOF}
${2:content}
${1:EOF}
""",
            description: "Here document"
        ),
        SnippetTemplate(
            label: "shebang",
            insertText: "#!/bin/bash",
            description: "Bash shebang"
        ),
        SnippetTemplate(
            label: "set-strict",
            insertText: "set -euo pipefail",
            description: "Strict error handling"
        ),
        SnippetTemplate(
            label: "getopts",
            insertText: """
while getopts "${1:hvf:}" opt; do
    case $opt in
        h)
            ${2:show_help}
            ;;
        v)
            ${3:verbose=true}
            ;;
        f)
            ${4:file="$OPTARG"}
            ;;
        \\?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
""",
            description: "Command line option parsing"
        ),
        SnippetTemplate(
            label: "test-file",
            insertText: """
if [[ -${1:f} "${2:filename}" ]]; then
    ${3:# file exists}
fi
""",
            description: "File test condition"
        ),
        SnippetTemplate(
            label: "test-var",
            insertText: """
if [[ -${1:z} "${2:variable}" ]]; then
    ${3:# variable is empty/unset}
fi
""",
            description: "Variable test condition"
        ),
        SnippetTemplate(
            label: "command-check",
            insertText: """
if command -v ${1:command} >/dev/null 2>&1; then
    ${2:# command exists}
else
    echo "${1:command} not found" >&2
    exit 1
fi
""",
            description: "Check if command exists"
        ),
        SnippetTemplate(
            label: "redirect",
            insertText: "${1:command} > ${2:output.txt} 2>&1",
            description: "Redirect output and errors"
        )
    ]

    // MARK: - Initialization

    init() {
        super.init(
            id: "shell-builtin",
            supportedLanguages: [.shell],
            triggerCharacters: [" ", "$", "(", ")", "[", "]", "|", "&", ";", "<", ">", "`", "\"", "'", "\\", "/", "-"],
            supportsSnippets: true
        )
    }

    // MARK: - BaseCompletionProvider Overrides

    override var keywords: [String] {
        // Shell keywords and built-in commands
        builtinCommands
    }

    override var functions: [String] {
        // System commands as functions
        systemCommands
    }

    override var snippets: [SnippetTemplate] {
        shellSnippets
    }

    // MARK: - Completions Override

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        _ = analyzeContext(context) // This will populate shellContext
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on Shell-specific context
        switch shellContext.type {
        case .command:
            items.append(contentsOf: createCommandCompletions(filter: shellContext.filter))

        case .variable:
            items.append(contentsOf: createVariableCompletions(filter: shellContext.filter))

        case .option:
            items.append(contentsOf: createOptionCompletions(for: shellContext.command, filter: shellContext.filter))

        case .path:
            items.append(contentsOf: createPathCompletions(filter: shellContext.filter))

        case .shellOperator:
            items.append(contentsOf: createOperatorCompletions(filter: shellContext.filter))

        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: shellContext.filter))

        case .general:
            items.append(contentsOf: createCommandCompletions(filter: shellContext.filter))
            items.append(contentsOf: createKeywordCompletions(filter: shellContext.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: shellContext.filter))
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

    // MARK: - Context Analysis Override

    override func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let beforeCursor = context.textBeforeCursor

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Store Shell-specific context for later use
        shellContext = analyzeShellContext(context)

        // Map Shell context to base context types
        switch shellContext.type {
        case .command:
            return ContextAnalysisResult(type: .function, filter: filter)

        case .variable, .option, .path, .shellOperator:
            // These will be handled in completions override
            return ContextAnalysisResult(type: .general, filter: filter)

        case .keyword:
            return ContextAnalysisResult(type: .keyword, filter: filter)

        case .general:
            return ContextAnalysisResult(type: .general, filter: filter)
        }
    }

    // MARK: - Shell-Specific Context Analysis

    private func analyzeShellContext(_ context: CompletionContextModel) -> ShellContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = context.textBeforeCursor

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for variable context
        if beforeCursor.hasSuffix("$") || filter.hasPrefix("$") {
            return ShellContextAnalysisResult(type: .variable, filter: filter)
        }

        // Check for option context (starts with -)
        if filter.hasPrefix("-") {
            let command = extractCurrentCommand(from: lineText)
            return ShellContextAnalysisResult(type: .option, filter: filter, command: command)
        }

        // Check for path context (contains / or ~)
        if filter.contains("/") || filter.hasPrefix("~") || filter.hasPrefix(".") {
            return ShellContextAnalysisResult(type: .path, filter: filter)
        }

        // Check for operator context
        if isOperatorContext(beforeCursor) {
            return ShellContextAnalysisResult(type: .shellOperator, filter: filter)
        }

        // Check for keyword context (control structures)
        if isKeywordContext(lineText, filter: filter) {
            return ShellContextAnalysisResult(type: .keyword, filter: filter)
        }

        // Check if we're at the start of a command
        if isAtCommandPosition(lineText, beforeCursor) {
            return ShellContextAnalysisResult(type: .command, filter: filter)
        }

        return ShellContextAnalysisResult(type: .general, filter: filter)
    }

    override func extractCurrentWord(from text: String) -> String {
        // Handle special cases for shell
        if text.hasSuffix("$") {
            return "$"
        }

        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-.$~/")).inverted)
        return components.last ?? ""
    }

    private func extractCurrentCommand(from lineText: String) -> String? {
        // Extract the command at the beginning of the line
        let words = lineText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.first
    }

    private func isOperatorContext(_ text: String) -> Bool {
        let operatorChars = ["&", "|", ";", "(", ")", "[", "]", "<", ">", "`"]
        return operatorChars.contains { text.hasSuffix($0) }
    }

    private func isKeywordContext(_ lineText: String, filter: String) -> Bool {
        // Check if we're in a context where keywords are expected
        let keywordTriggers = ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac"]

        // Check if the line starts with or contains keyword triggers
        for keyword in keywordTriggers {
            if lineText.hasPrefix(keyword) || lineText.contains(" \(keyword) ") {
                return true
            }
        }

        // Check if the filter itself looks like a keyword
        return builtinCommands.contains { $0.hasPrefix(filter.lowercased()) }
    }

    private func isAtCommandPosition(_ lineText: String, _ beforeCursor: String) -> Bool {
        // We're at command position if:
        // 1. Line is empty or starts with the current word
        // 2. We're after a command separator (;, &&, ||, |)
        // 3. We're after a newline or opening parenthesis

        if lineText.isEmpty {
            return true
        }

        let separators = [";", "&&", "||", "|", "(", "\n"]
        for separator in separators {
            if beforeCursor.hasSuffix(separator + " ") || beforeCursor.hasSuffix(separator) {
                return true
            }
        }

        // Check if we're at the beginning of the line (after whitespace)
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.count <= 1
    }

    // MARK: - Override Keyword Completions

    override func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                let insertText: String

                // Add common patterns for certain keywords
                switch keyword {
                case "if":
                    insertText = "if [[ $0 ]]; then"

                case "for":
                    insertText = "for \(keyword) in $0; do"

                case "while":
                    insertText = "while [[ $0 ]]; do"

                case "function":
                    insertText = "function $0() {"

                case "case":
                    insertText = "case $0 in"

                default:
                    insertText = keyword
                }

                return CompletionItemModel(
                    label: keyword,
                    insertText: insertText,
                    kind: .keyword,
                    detail: "Shell keyword",
                    priority: 85,
                    preselect: keyword == filter
                )
            }
    }

    // MARK: - Shell-Specific Completion Creation Methods

    private func createCommandCompletions(filter: String) -> [CompletionItemModel] {
        let allCommands = builtinCommands + systemCommands

        return allCommands
            .filter { command in
                filter.isEmpty || command.localizedCaseInsensitiveContains(filter)
            }
            .map { command in
                let priority = builtinCommands.contains(command) ? 85 : 75
                let detail = builtinCommands.contains(command) ? "Built-in command" : "System command"

                return CompletionItemModel(
                    label: command,
                    insertText: command,
                    kind: .function,
                    detail: detail,
                    priority: priority,
                    preselect: command == filter
                )
            }
    }

    private func createVariableCompletions(filter: String) -> [CompletionItemModel] {
        environmentVariables
            .filter { variable in
                let filterToUse = filter.hasPrefix("$") ? filter : "$\(filter)"
                return variable.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { variable in
                CompletionItemModel(
                    label: variable,
                    insertText: variable.hasPrefix("$") ? String(variable.dropFirst()) : variable,
                    kind: .variable,
                    detail: "Environment variable",
                    priority: 80
                )
            }
    }

    private func createOptionCompletions(for _: String?, filter: String) -> [CompletionItemModel] {
        // For now, return common options
        // In a real implementation, this could be command-specific
        commonOptions
            .filter { option in
                filter.isEmpty || option.localizedCaseInsensitiveContains(filter)
            }
            .map { option in
                CompletionItemModel(
                    label: option,
                    insertText: option,
                    kind: .property,
                    detail: "Command option",
                    priority: 70
                )
            }
    }

    private func createPathCompletions(filter: String) -> [CompletionItemModel] {
        // Basic path completions - in a real implementation, this would
        // scan the filesystem based on the current path
        let commonPaths = [
            "/", "/usr", "/usr/bin", "/usr/local", "/usr/local/bin", "/bin", "/sbin",
            "/etc", "/var", "/var/log", "/tmp", "/home", "/opt", "/dev", "/proc",
            "~", "~/", "../", "./", ".", ".."
        ]

        return commonPaths
            .filter { path in
                filter.isEmpty || path.localizedCaseInsensitiveContains(filter)
            }
            .map { path in
                CompletionItemModel(
                    label: path,
                    insertText: path,
                    kind: .folder,
                    detail: "Path",
                    priority: 65
                )
            }
    }

    private func createOperatorCompletions(filter: String) -> [CompletionItemModel] {
        operators
            .filter { op in
                filter.isEmpty || op.localizedCaseInsensitiveContains(filter)
            }
            .map { op in
                let detail: String
                switch op {
                case "&&":
                    detail = "Logical AND"

                case "||":
                    detail = "Logical OR"

                case "|":
                    detail = "Pipe"

                case "&":
                    detail = "Background process"

                case ";":
                    detail = "Command separator"

                case ">":
                    detail = "Redirect output"

                case ">>":
                    detail = "Append output"

                case "<":
                    detail = "Input redirection"

                case "2>":
                    detail = "Redirect stderr"

                case "2>&1":
                    detail = "Redirect stderr to stdout"

                default:
                    detail = "Shell operator"
                }

                return CompletionItemModel(
                    label: op,
                    insertText: op,
                    kind: .operator,
                    detail: detail,
                    priority: 60
                )
            }
    }

    override func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
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

private struct ShellContextAnalysisResult {
    enum CompletionType {
        case command
        case variable
        case option
        case path
        case shellOperator
        case keyword
        case general
    }

    let type: CompletionType
    let filter: String
    let command: String?

    init(type: CompletionType, filter: String, command: String? = nil) {
        self.type = type
        self.filter = filter
        self.command = command
    }
}
