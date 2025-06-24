import Foundation

// Text provider types for predicate support
public typealias TextProvider = (NSRange, Any?) -> String?
public typealias TextSnapshotProvider = (NSRange, Any?) -> String?

extension String {
	/// Produces a `TextProvider` for use with `Predicate` resolution.
	@available(*, deprecated, renamed: "predicateTextProvider")
	public var cursorTextProvider: TextProvider {
		return { (nsRange, _) in
			guard let range = Range<String.Index>(nsRange, in: self) else {
				return nil
			}

			return String(self[range])
		}
	}

	public var predicateTextProvider: TextProvider {
		predicateTextSnapshotProvider
	}
	
	public var predicateTextSnapshotProvider: TextSnapshotProvider {
		{ (nsRange, _) in
			guard let range = Range<String.Index>(nsRange, in: self) else {
				return nil
			}

			return String(self[range])
		}
	}
}
