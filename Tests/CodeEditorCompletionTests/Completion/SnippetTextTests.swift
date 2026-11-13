@testable import CodeEditorLanguages
import Foundation
import Testing

/// Completions are inserted literally, so snippet syntax must never reach
/// the document.
@Suite struct SnippetTextTests {
    @Test func placeholdersExpandToTheirText() {
        #expect(SnippetText.plainText(fromSnippet: "greet(name: ${1:String}, times: ${2:Int})") == "greet(name: String, times: Int)")
        #expect(SnippetText.plainText(fromSnippet: "print($0)") == "print()")
        #expect(SnippetText.plainText(fromSnippet: "f(${1}, $2)$0") == "f(, )")
    }

    @Test func nestedPlaceholdersChoicesVariablesAndEscapes() {
        #expect(SnippetText.plainText(fromSnippet: "${1:outer ${2:inner}}") == "outer inner")
        #expect(SnippetText.plainText(fromSnippet: "${1|public,private|} x") == "public x")
        #expect(SnippetText.plainText(fromSnippet: "${TM_FILENAME:file} $TM_SELECTED_TEXT") == "file ")
        #expect(SnippetText.plainText(fromSnippet: #"cost \$5 \} \\ ${1:a\}b}"#) == #"cost $5 } \ a}b"#)
        #expect(SnippetText.plainText(fromSnippet: "price: $ and ${ x") == "price: $ and ${ x")
    }

    @Test func builtInFunctionAndSnippetCompletionsInsertPlainText() {
        let functions = SharedCompletionBuilder.createFunctionCompletions(from: ["print"], filter: "", languageName: "Swift")
        #expect(functions.first?.insertText == "print()")

        let snippets = SharedCompletionBuilder.createSnippetCompletions(
            from: [SnippetTemplate(label: "func", insertText: "func ${1:name}() {\n    $0\n}", description: "")],
            filter: "",
            languageName: "Swift"
        )
        #expect(snippets.first?.insertText == "func name() {\n    \n}")
    }
}
