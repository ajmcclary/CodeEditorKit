// Kept identical in Tests/CodeEditorUITests/Snapshots/ and
// Tests/CodeEditorKitTests/Layout/ (the two targets with image snapshots;
// there is no shared test-support target). Change both copies together.
#if canImport(AppKit)
import AppKit
import CoreImage
import ImageIO
import SnapshotTesting
import UniformTypeIdentifiers
import XCTest

/// Display-scale-independent image snapshots.
///
/// SnapshotTesting's `NSView`/`NSImage` strategies render at the current
/// display's backing scale (`bitmapImageRepForCachingDisplay`) and compare
/// through `NSImage.cgImage(forProposedRect: nil, …)`, which re-rasterizes at
/// that scale too. References recorded on a Retina Mac (2x) therefore cannot
/// match on a headless CI runner (1x display). These strategies render into an
/// explicitly sized bitmap at a fixed scale and compare native pixels decoded
/// with ImageIO, mirroring SnapshotTesting's comparison semantics
/// (`precision` = fraction of matching pixels; `perceptualPrecision` =
/// per-pixel CIE ΔE tolerance).
enum NativeImageSnapshot {
    static let scale: CGFloat = 2

    /// A blank bitmap of `size` points at `scale` pixels per point.
    static func bitmap(size: CGSize, scale: CGFloat = scale) -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * scale).rounded()),
            pixelsHigh: Int((size.height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            preconditionFailure("could not allocate a \(size) bitmap")
        }
        rep.size = size
        return rep
    }

    /// Renders `view` the way SnapshotTesting does (`cacheDisplay`), but into
    /// a fixed-scale bitmap.
    @MainActor
    static func render(_ view: NSView, scale: CGFloat = scale) -> CGImage {
        guard view.bounds.width > 0, view.bounds.height > 0 else {
            preconditionFailure("view not renderable at size \(view.bounds.size)")
        }
        let rep = bitmap(size: view.bounds.size, scale: scale)
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let image = rep.cgImage else { preconditionFailure("bitmap has no CGImage") }
        return image
    }
}

extension Snapshotting where Value == NSView, Format == CGImage {
    @MainActor
    static func nativeImage(precision: Float = 1, perceptualPrecision: Float = 1) -> Snapshotting {
        Snapshotting<CGImage, CGImage>.nativeImage(precision: precision, perceptualPrecision: perceptualPrecision)
            .pullback { view in MainActor.assumeIsolated { NativeImageSnapshot.render(view) } }
    }
}

extension Snapshotting where Value == CGImage, Format == CGImage {
    static func nativeImage(precision: Float = 1, perceptualPrecision: Float = 1) -> Snapshotting {
        Snapshotting(
            pathExtension: "png",
            diffing: .nativeImage(precision: precision, perceptualPrecision: perceptualPrecision)
        )
    }
}

extension Diffing where Value == CGImage {
    static func nativeImage(precision: Float, perceptualPrecision: Float) -> Diffing {
        Diffing(
            toData: { _nativePNG($0) },
            fromData: { _decodePNG($0) },
            diff: { old, new in
                _compareNative(old, new, precision: precision, perceptualPrecision: perceptualPrecision)
                    .map { ($0, []) }
            }
        )
    }
}

private func _nativePNG(_ image: CGImage) -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData, UTType.png.identifier as CFString, 1, nil
    ) else { preconditionFailure("could not create a PNG encoder") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { preconditionFailure("could not encode PNG") }
    return data as Data
}

private func _decodePNG(_ data: Data) -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        preconditionFailure("snapshot reference is not a decodable image")
    }
    return image
}

/// RGBA8 premultiplied-last sRGB bytes, `width * 4` per row; empty if the
/// image could not be drawn.
private func _canonicalRGBA(_ image: CGImage) -> [UInt8] {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    return drawn ? bytes : []
}

private func _compareNative(
    _ old: CGImage, _ new: CGImage, precision: Float, perceptualPrecision: Float
) -> String? {
    guard old.width == new.width, old.height == new.height else {
        return "Newly-taken snapshot (\(new.width)×\(new.height) px) does not match reference (\(old.width)×\(old.height) px)."
    }
    // Like SnapshotTesting, compare against the new image after a PNG round trip.
    let newer = _decodePNG(_nativePNG(new))
    let oldBytes = _canonicalRGBA(old)
    let newBytes = _canonicalRGBA(newer)
    guard !oldBytes.isEmpty, !newBytes.isEmpty else {
        return "Snapshot pixel data could not be loaded."
    }
    if oldBytes == newBytes { return nil }
    if precision >= 1, perceptualPrecision >= 1 {
        return "Newly-taken snapshot does not match reference."
    }
    if perceptualPrecision < 1 {
        return _perceptuallyCompare(old, newer, precision: precision, perceptualPrecision: perceptualPrecision)
    }
    var different = 0
    var index = 0
    while index < oldBytes.count {
        if oldBytes[index] != newBytes[index] { different += 1 }
        index += 1
    }
    guard different > Int((1 - precision) * Float(oldBytes.count)) else { return nil }
    let actual = 1 - Float(different) / Float(oldBytes.count)
    return "Actual image precision \(actual) is less than required \(precision)"
}

/// SnapshotTesting's CPU path: per-pixel CIE ΔE (0...100) via `CILabDeltaE`;
/// a pixel fails when ΔE exceeds `(1 - perceptualPrecision) * 100`.
private func _perceptuallyCompare(
    _ old: CGImage, _ new: CGImage, precision: Float, perceptualPrecision: Float
) -> String? {
    let delta = CIImage(cgImage: old).applyingFilter("CILabDeltaE", parameters: ["inputImage2": CIImage(cgImage: new)])
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    let width = old.width, height = old.height
    var values = [Float](repeating: 0, count: width * height)
    values.withUnsafeMutableBytes { buffer in
        guard let base = buffer.baseAddress else { return }
        context.render(
            delta,
            toBitmap: base,
            rowBytes: width * MemoryLayout<Float>.stride,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .Rf,
            colorSpace: nil
        )
    }
    let threshold = (1 - perceptualPrecision) * 100
    var failing = 0
    var maximumDeltaE: Float = 0
    for deltaE in values where deltaE > threshold {
        failing += 1
        maximumDeltaE = max(maximumDeltaE, deltaE)
    }
    let actualPrecision = 1 - Float(failing) / Float(width * height)
    guard actualPrecision < precision else { return nil }
    let lowestPerceptual = 1 - min(maximumDeltaE / 100, 1)
    return """
    The percentage of pixels that match \(actualPrecision) is less than required \(precision)
    The lowest perceptual color precision \(lowestPerceptual) is less than required \(perceptualPrecision)
    """
}
#endif
