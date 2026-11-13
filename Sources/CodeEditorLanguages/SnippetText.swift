import Foundation

/// Turns LSP / TextMate snippet syntax into the plain text it would insert.
///
/// The editor inserts a completion's `insertText` literally and has no
/// snippet session (tab stops, linked placeholders), so snippet syntax must
/// be expanded before it reaches the document: `$1` and `$0` disappear,
/// `${1:name}` becomes `name` (nested placeholders included), `${1|a,b|}`
/// becomes `a`, `${VAR:default}` becomes `default`, `$VAR` disappears, and
/// `\$`, `\}`, `\\` (and `\,`, `\|` inside a choice) unescape.
package enum SnippetText {
    package static func plainText(fromSnippet snippet: String) -> String {
        var parser = Parser(characters: Array(snippet))
        return parser.parse(until: nil)
    }

    private struct Parser {
        let characters: [Character]
        var index = 0

        init(characters: [Character]) {
            self.characters = characters
        }

        private var current: Character? {
            index < characters.count ? characters[index] : nil
        }

        /// Parses text up to (not including) an unescaped `terminator`.
        mutating func parse(until terminator: Character?) -> String {
            var output = ""
            while let character = current {
                if character == terminator {
                    return output
                }
                if character == "\\", index + 1 < characters.count,
                   ["$", "}", "\\"].contains(characters[index + 1]) {
                    output.append(characters[index + 1])
                    index += 2
                    continue
                }
                if character == "$", let expansion = parseDollar() {
                    output += expansion
                    continue
                }
                output.append(character)
                index += 1
            }
            return output
        }

        /// At a `$`: consumes a tab stop, placeholder, choice or variable and
        /// returns its plain text, or returns nil (consuming nothing) when the
        /// `$` is literal.
        private mutating func parseDollar() -> String? {
            let start = index
            index += 1 // `$`
            if let next = current, next.isASCII, next.isNumber || next.isLetter || next == "_" {
                // `$1` / `$name`
                while let character = current, character.isASCII,
                      character.isNumber || character.isLetter || character == "_" {
                    index += 1
                }
                return ""
            }
            guard current == "{" else {
                index = start
                return nil
            }
            index += 1 // `{`
            var name = ""
            while let character = current, character.isASCII,
                  character.isNumber || character.isLetter || character == "_" {
                name.append(character)
                index += 1
            }
            guard !name.isEmpty else {
                index = start
                return nil
            }
            switch current {
            case "}":
                index += 1
                return ""

            case ":":
                index += 1
                let placeholder = parse(until: "}")
                if current == "}" { index += 1 }
                return placeholder

            case "|":
                index += 1
                return parseFirstChoice()

            default:
                index = start
                return nil
            }
        }

        /// After `${n|`: returns the first choice and consumes through `|}`.
        private mutating func parseFirstChoice() -> String {
            var choices: [String] = [""]
            while let character = current {
                if character == "\\", index + 1 < characters.count,
                   [",", "|", "\\", "$", "}"].contains(characters[index + 1]) {
                    choices[choices.count - 1].append(characters[index + 1])
                    index += 2
                    continue
                }
                if character == "|", index + 1 < characters.count, characters[index + 1] == "}" {
                    index += 2
                    break
                }
                if character == "," {
                    choices.append("")
                } else {
                    choices[choices.count - 1].append(character)
                }
                index += 1
            }
            return choices.first ?? ""
        }
    }
}
