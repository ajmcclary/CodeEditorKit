import CodeEditorPlugin
import Foundation

// Sample snippets contain print/println/echo statements as part of the
// demo code — they are string literals shown in the editor, not Swift
// statements that execute. Suppress the rule for this whole file.
// swiftlint:disable no_print_statements

/// Per-language sample snippets used by the sample app's editor pane.
/// Each entry is short, self-contained, and exercises the syntax features
/// the highlighter cares about (keywords, strings, numbers, comments,
/// punctuation). Fed in by `DocumentStore` whenever the user switches
/// languages from the sidebar picker or the command palette.
enum SampleCodeCatalog {
    /// Returns the canonical sample text for the given language.
    static func text(for language: Language) -> String {
        switch language {
        case .swift:      return swiftSample
        case .javascript: return javascriptSample
        case .typescript: return typescriptSample
        case .python:     return pythonSample
        case .go:         return goSample
        case .rust:       return rustSample
        case .c:          return cSample
        case .cpp:        return cppSample
        case .java:       return javaSample
        case .html:       return htmlSample
        case .css:        return cssSample
        case .json:       return jsonSample
        case .markdown:   return markdownSample
        case .yaml:       return yamlSample
        case .xml:        return xmlSample
        case .sql:        return sqlSample
        case .ruby:       return rubySample
        case .php:        return phpSample
        case .shell:      return shellSample
        case .plainText:  return plainTextSample
        }
    }

    // MARK: - Snippets

    private static let swiftSample = """
    import Foundation

    /// Greets the named person and returns the rendered string.
    func greet(_ name: String, times: Int = 1) -> String {
        var lines: [String] = []
        for index in 0..<times {
            lines.append("Hello, \\(name)! (\\(index + 1))")
        }
        return lines.joined(separator: "\\n")
    }

    let names = ["Ada", "Grace", "Linus"]
    for name in names {
        print(greet(name, times: 2))
    }
    """

    private static let javascriptSample = """
    // Greets the named person and returns the rendered string.
    function greet(name, times = 1) {
        const lines = [];
        for (let i = 0; i < times; i++) {
            lines.push(`Hello, ${name}! (${i + 1})`);
        }
        return lines.join("\\n");
    }

    const names = ["Ada", "Grace", "Linus"];
    for (const name of names) {
        console.log(greet(name, 2));
    }
    """

    private static let typescriptSample = """
    // Greets the named person and returns the rendered string.
    function greet(name: string, times: number = 1): string {
        const lines: string[] = [];
        for (let i = 0; i < times; i++) {
            lines.push(`Hello, ${name}! (${i + 1})`);
        }
        return lines.join("\\n");
    }

    const names: readonly string[] = ["Ada", "Grace", "Linus"];
    for (const name of names) {
        console.log(greet(name, 2));
    }
    """

    private static let pythonSample = #"""
    """Greeting demo — small sample for syntax highlighting."""


    def greet(name: str, times: int = 1) -> str:
        """Greets the named person and returns the rendered string."""
        lines = []
        for i in range(times):
            lines.append(f"Hello, {name}! ({i + 1})")
        return "\n".join(lines)


    if __name__ == "__main__":
        names = ["Ada", "Grace", "Linus"]
        for name in names:
            print(greet(name, times=2))
    """#

    private static let goSample = """
    package main

    import "fmt"

    // Greet returns the rendered greeting string.
    func Greet(name string, times int) string {
        out := ""
        for i := 0; i < times; i++ {
            out += fmt.Sprintf("Hello, %s! (%d)\\n", name, i+1)
        }
        return out
    }

    func main() {
        names := []string{"Ada", "Grace", "Linus"}
        for _, name := range names {
            fmt.Print(Greet(name, 2))
        }
    }
    """

    private static let rustSample = """
    /// Greets the named person and returns the rendered string.
    fn greet(name: &str, times: u32) -> String {
        let mut out = String::new();
        for i in 0..times {
            out.push_str(&format!("Hello, {}! ({})\\n", name, i + 1));
        }
        out
    }

    fn main() {
        let names = ["Ada", "Grace", "Linus"];
        for name in names.iter() {
            print!("{}", greet(name, 2));
        }
    }
    """

    private static let cSample = """
    #include <stdio.h>
    #include <string.h>

    /* Greets the named person and writes the rendered string into out. */
    void greet(const char *name, int times, char *out, size_t cap) {
        out[0] = '\\0';
        for (int i = 0; i < times; i++) {
            char line[64];
            snprintf(line, sizeof line, "Hello, %s! (%d)\\n", name, i + 1);
            strncat(out, line, cap - strlen(out) - 1);
        }
    }

    int main(void) {
        const char *names[] = { "Ada", "Grace", "Linus" };
        char buf[256];
        for (int i = 0; i < 3; i++) {
            greet(names[i], 2, buf, sizeof buf);
            printf("%s", buf);
        }
        return 0;
    }
    """

    private static let cppSample = """
    #include <iostream>
    #include <string>
    #include <vector>

    // Greets the named person and returns the rendered string.
    std::string greet(const std::string& name, int times = 1) {
        std::string out;
        for (int i = 0; i < times; ++i) {
            out += "Hello, " + name + "! (" + std::to_string(i + 1) + ")\\n";
        }
        return out;
    }

    int main() {
        std::vector<std::string> names { "Ada", "Grace", "Linus" };
        for (const auto& name : names) {
            std::cout << greet(name, 2);
        }
    }
    """

    private static let javaSample = """
    import java.util.List;

    public class Greeting {
        /** Greets the named person and returns the rendered string. */
        public static String greet(String name, int times) {
            StringBuilder out = new StringBuilder();
            for (int i = 0; i < times; i++) {
                out.append("Hello, ").append(name)
                   .append("! (").append(i + 1).append(")\\n");
            }
            return out.toString();
        }

        public static void main(String[] args) {
            List<String> names = List.of("Ada", "Grace", "Linus");
            for (String name : names) {
                System.out.print(greet(name, 2));
            }
        }
    }
    """

    private static let htmlSample = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Sample Page</title>
        <style>
            body { font-family: system-ui, sans-serif; padding: 2rem; }
            .greeting { color: #ff9933; }
        </style>
    </head>
    <body>
        <h1 class="greeting">Hello, World!</h1>
        <p>A small <a href="https://example.com">sample document</a> for syntax highlighting.</p>
        <ul>
            <li>Ada</li>
            <li>Grace</li>
            <li>Linus</li>
        </ul>
    </body>
    </html>
    """

    private static let cssSample = """
    /* Demo card component — uses CSS variables for theme tokens. */
    :root {
        --bg-elevated: #14181f;
        --fg-base: #f2e7d8;
        --accent: #ff9933;
        --radius: 8px;
    }

    .card {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
        padding: 1rem 1.25rem;
        background: var(--bg-elevated);
        color: var(--fg-base);
        border-radius: var(--radius);
        border: 1px solid rgba(255, 153, 51, 0.12);
    }

    .card__title {
        font-size: 1rem;
        font-weight: 600;
        color: var(--accent);
    }
    """

    private static let jsonSample = """
    {
        "$schema": "https://example.com/schema.json",
        "name": "code-editor-sample",
        "version": "1.2.0",
        "active": true,
        "people": [
            { "name": "Ada", "role": "founder" },
            { "name": "Grace", "role": "engineer" },
            { "name": "Linus", "role": "maintainer" }
        ],
        "settings": {
            "theme": "LCARS Dark",
            "tabWidth": 4,
            "wrapLines": false
        }
    }
    """

    private static let markdownSample = ##"""
    # Sample Document

    A small Markdown document for **syntax highlighting**.

    ## Features

    - Bold and *italic* emphasis
    - [Inline links](https://example.com)
    - `inline code` snippets
    - Fenced code blocks:

    ```swift
    func greet(_ name: String) -> String {
        "Hello, \(name)!"
    }
    ```

    > Blockquotes for emphasis.

    | Name  | Role        |
    | ----- | ----------- |
    | Ada   | Founder     |
    | Grace | Engineer    |
    | Linus | Maintainer  |
    """##

    private static let yamlSample = """
    # Sample configuration file for syntax highlighting.
    name: code-editor-sample
    version: 1.2.0
    active: true

    people:
      - name: Ada
        role: founder
      - name: Grace
        role: engineer
      - name: Linus
        role: maintainer

    settings:
      theme: LCARS Dark
      tabWidth: 4
      wrapLines: false
    """

    private static let xmlSample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Sample document for syntax highlighting. -->
    <people xmlns="https://example.com/people">
        <person id="1">
            <name>Ada</name>
            <role>founder</role>
        </person>
        <person id="2">
            <name>Grace</name>
            <role>engineer</role>
        </person>
        <person id="3">
            <name>Linus</name>
            <role>maintainer</role>
        </person>
    </people>
    """

    private static let sqlSample = """
    -- Demo schema and queries for syntax highlighting.
    CREATE TABLE people (
        id      INTEGER PRIMARY KEY,
        name    TEXT NOT NULL,
        role    TEXT NOT NULL,
        active  BOOLEAN DEFAULT TRUE
    );

    INSERT INTO people (name, role) VALUES
        ('Ada',   'founder'),
        ('Grace', 'engineer'),
        ('Linus', 'maintainer');

    SELECT name, role
      FROM people
     WHERE active = TRUE
     ORDER BY name ASC;
    """

    private static let rubySample = """
    # Greets the named person and returns the rendered string.
    def greet(name, times: 1)
      lines = []
      times.times do |i|
        lines << "Hello, \\#{name}! (\\#{i + 1})"
      end
      lines.join("\\n")
    end

    names = ["Ada", "Grace", "Linus"]
    names.each do |name|
      puts greet(name, times: 2)
    end
    """

    private static let phpSample = #"""
    <?php
    // Greets the named person and returns the rendered string.
    function greet(string $name, int $times = 1): string {
        $lines = [];
        for ($i = 0; $i < $times; $i++) {
            $lines[] = "Hello, {$name}! (" . ($i + 1) . ")";
        }
        return implode("\n", $lines);
    }

    $names = ["Ada", "Grace", "Linus"];
    foreach ($names as $name) {
        echo greet($name, 2) . "\n";
    }
    """#

    private static let shellSample = """
    #!/usr/bin/env bash
    # Greets each named person twice.

    set -euo pipefail

    greet() {
        local name="$1"
        local times="${2:-1}"
        for ((i = 1; i <= times; i++)); do
            echo "Hello, ${name}! (${i})"
        done
    }

    names=("Ada" "Grace" "Linus")
    for name in "${names[@]}"; do
        greet "$name" 2
    done
    """

    private static let plainTextSample = """
    Plain text — no syntax to highlight.

    A small README-style document showing how the editor handles
    free-form text. Line wrapping, selection, and find-replace all
    work the same as in any other language.

      • Editor renders 20+ languages with theme-aware highlighting.
      • Switch languages via the Language picker on the left.
      • Customize the theme via the Theme picker.
      • Tweak knobs in the Display / Layout / Behavior sections.

    — end of sample —
    """
}

// swiftlint:enable no_print_statements
