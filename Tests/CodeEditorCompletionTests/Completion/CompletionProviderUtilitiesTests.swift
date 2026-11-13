@testable import CodeEditorCompletion
import Foundation
import Testing

@Suite struct CompletionProviderUtilitiesTests {
    @Test func functionCallContextStopsAtTheInnermostOpenCall() {
        let text = "foo(a, b); bar(x, "
        let context = CompletionProviderUtilities.extractFunctionCallContext(from: text, at: text.utf16.count)
        #expect(context.function == "bar")
        #expect(context.parameterIndex == 1)
    }
}
