import Foundation

extension Duration {
    /// Total duration expressed in milliseconds as a `Double`.
    var totalMilliseconds: Double {
        let seconds = Double(components.seconds)
        let attos = Double(components.attoseconds)
        return seconds * 1_000 + attos / 1_000_000_000_000_000
    }
}
