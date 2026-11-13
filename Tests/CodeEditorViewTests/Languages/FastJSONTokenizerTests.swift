@testable import CodeEditorSyntaxHighlighting
import Foundation
import Testing

@Suite struct FastJSONTokenizerTests {
    @Test func sameLengthEditIsTokenizedAgain() {
        let tokenizer = FastJSONTokenizer()
        let numbers = tokenizer.tokenize("1234")
        #expect(numbers.map(\.type) == [.number])
        let strings = tokenizer.tokenize("\"ab\"")
        #expect(strings.map(\.type) == [.string])
    }

    @Test func defaultRangeCoversTheWholeUTF16Text() {
        let text = "{\"a\": \"😀😀\",\r\n \"b\": 1}"
        let tokens = FastJSONTokenizer().tokenize(text)
        let numberRange = tokens.first { $0.type == .number }?.range
        let one = text.utf16.count - 2
        #expect(numberRange == NSRange(location: one, length: 1))
        #expect(tokens.last?.type == .closeBrace)
    }
}
