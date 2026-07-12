import Foundation

/// Shared wire representation for LSP string-or-integer unions.
package enum StringOrInteger: Codable, Hashable, Sendable {
    case string(String)
    case integer(Int)

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .integer(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            Self.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected string or integer"
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)

        case .integer(let value):
            try container.encode(value)
        }
    }
}
