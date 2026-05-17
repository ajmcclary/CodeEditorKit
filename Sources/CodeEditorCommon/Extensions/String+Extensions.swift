// swiftlint:disable missing_docs
import Foundation

// Text provider types for predicate support
/// Provides text content for a given range and context
public typealias TextProvider = (NSRange, Any?) -> String?
/// Provides snapshot of text content for a given range and context
public typealias TextSnapshotProvider = (NSRange, Any?) -> String?

extension String {
    public static var nativeUTF16Encoding: String.Encoding {
        #if _endian(little)
        return .utf16LittleEndian
        #else
        return .utf16BigEndian
        #endif
    }

    public func data(at byteOffset: Int, limit: Int, using encoding: String.Encoding, chunkSize: Int) -> Data? {
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

    public var predicateTextProvider: TextProvider {
        predicateTextSnapshotProvider
    }

    public var predicateTextSnapshotProvider: TextSnapshotProvider {
        { nsRange, _ in
            guard let range = Range<String.Index>(nsRange, in: self) else {
                return nil
            }

            return String(self[range])
        }
    }
}

// swiftlint:enable missing_docs
