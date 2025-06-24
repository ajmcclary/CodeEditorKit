import Foundation

// Text provider types for predicate support
public typealias TextProvider = (NSRange, Any?) -> String?
public typealias TextSnapshotProvider = (NSRange, Any?) -> String?

extension String {
    static var nativeUTF16Encoding: String.Encoding {
        #if _endian(little)
        return .utf16LittleEndian
        #else
        return .utf16BigEndian
        #endif
    }

    func data(at byteOffset: Int, limit: Int, using encoding: String.Encoding, chunkSize: Int) -> Data? {
        // Ensure encoding is valid for this operation
        precondition(
            encoding == .utf16 || encoding == .utf16BigEndian || encoding == .utf16LittleEndian || encoding == .utf8
        )

        let location = byteOffset / 2

        let end = min(location + (chunkSize / 2), limit)

        if location > end {
            assertionFailure("location is greater than end")
            return nil
        }

        let range = NSRange(location ..< end)
        guard let stringRange = Range(range, in: self) else {
            return nil
        }

        let substring = self[stringRange]

        // have to remove the bom from the string
        return substring.data(using: encoding)
    }

    /// Produces a `TextProvider` for use with `Predicate` resolution.
    @available(*, deprecated, renamed: "predicateTextProvider") var cursorTextProvider: TextProvider {
        { nsRange, _ in
            guard let range = Range<String.Index>(nsRange, in: self) else {
                return nil
            }

            return String(self[range])
        }
    }

    var predicateTextProvider: TextProvider {
        predicateTextSnapshotProvider
    }

    var predicateTextSnapshotProvider: TextSnapshotProvider {
        { nsRange, _ in
            guard let range = Range<String.Index>(nsRange, in: self) else {
                return nil
            }

            return String(self[range])
        }
    }
}
