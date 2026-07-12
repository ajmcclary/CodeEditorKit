@testable import CodeEditorLSP
import Foundation
import Testing

@Suite("LSP string-or-integer codec")
struct StringOrIntegerTests {
    @Test("kernel and semantic wrappers round-trip both wire cases")
    func roundTrips() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        #expect(try decoder.decode(StringOrInteger.self, from: Data("42".utf8)) == .integer(42))
        #expect(try decoder.decode(StringOrInteger.self, from: Data("\"E1\"".utf8)) == .string("E1"))

        let requestNumber = try decoder.decode(RequestId.self, from: Data("42".utf8))
        let requestString = try decoder.decode(RequestId.self, from: Data("\"id\"".utf8))
        #expect(try encoder.encode(requestNumber) == Data("42".utf8))
        #expect(try encoder.encode(requestString) == Data("\"id\"".utf8))

        let diagnosticNumber = try decoder.decode(DiagnosticCode.self, from: Data("7".utf8))
        let diagnosticString = try decoder.decode(DiagnosticCode.self, from: Data("\"W7\"".utf8))
        #expect(try encoder.encode(diagnosticNumber) == Data("7".utf8))
        #expect(try encoder.encode(diagnosticString) == Data("\"W7\"".utf8))
    }

    @Test(arguments: ["true", "null", "{}", "[]"])
    func rejectsOtherJSONShapes(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(StringOrInteger.self, from: Data(json.utf8))
        }
    }
}
