import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A flat JPEG of the given pixel size, optionally tagged with an EXIF orientation, as a camera would deliver it.
/// It is the fixtures' orange unless a grey level is given.
func makeJPEG(width: Int, height: Int, orientation: CGImagePropertyOrientation = .up, grey: Double? = nil) -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    let fill = grey.map { CGColor(srgbRed: $0, green: $0, blue: $0, alpha: 1) }
        ?? CGColor(srgbRed: 200 / 255, green: 120 / 255, blue: 40 / 255, alpha: 1)
    context.setFillColor(fill)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(
        destination, context.makeImage()!, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
    )
    CGImageDestinationFinalize(destination)
    return data as Data
}

/// The pixel size and metadata of an encoded picture.
func describe(_ data: Data) -> (width: Int, height: Int, properties: [CFString: Any])? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (width, height, properties)
}

/// One sRGB pixel as 0...255 components.
struct Pixel: Equatable, CustomStringConvertible {
    var red: Int
    var green: Int
    var blue: Int

    var description: String { "(\(red), \(green), \(blue))" }

    func isClose(to other: Pixel, tolerance: Int = 2) -> Bool {
        abs(red - other.red) <= tolerance && abs(green - other.green) <= tolerance && abs(blue - other.blue) <= tolerance
    }
}

extension CIContext {
    /// Reads one pixel, counting `x` from the left and `y` from the top.
    func pixel(of image: CIImage, x: Int, y: Int) -> Pixel {
        var bytes = [UInt8](repeating: 0, count: 4)
        let row = Int(image.extent.maxY) - 1 - y
        render(
            image, toBitmap: &bytes, rowBytes: 4,
            bounds: CGRect(x: Int(image.extent.minX) + x, y: row, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return Pixel(red: Int(bytes[0]), green: Int(bytes[1]), blue: Int(bytes[2]))
    }

    /// Reads every pixel of a region given in Core Image's coordinates, row by row.
    func pixels(of image: CIImage, in region: CGRect) -> [Pixel] {
        let width = Int(region.width)
        let height = Int(region.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        render(
            image, toBitmap: &bytes, rowBytes: width * 4, bounds: region,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return stride(from: 0, to: bytes.count, by: 4).map {
            Pixel(red: Int(bytes[$0]), green: Int(bytes[$0 + 1]), blue: Int(bytes[$0 + 2]))
        }
    }
}

extension CIImage {
    /// A flat sRGB colour of the given pixel size.
    static func flat(red: Double, green: Double, blue: Double, width: Int, height: Int) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}

/// Writes a short movie of one flat orange, as a recording would leave it. A portrait recording is stored
/// sideways with a rotation beside it, which `isPortrait` reproduces.
func makeMovie(at url: URL, seconds: Double = 1, width: Int = 320, height: Int = 240, isPortrait: Bool = false) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
    ])
    if isPortrait {
        input.transform = CGAffineTransform(rotationAngle: .pi / 2)
    }
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    guard let buffer else { throw CocoaError(.fileWriteUnknown) }
    CVPixelBufferLockBaseAddress(buffer, [])
    if let base = CVPixelBufferGetBaseAddress(buffer) {
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<height {
            for column in 0..<width {
                let pixel = bytes + row * rowBytes + column * 4
                pixel[0] = 40; pixel[1] = 120; pixel[2] = 200; pixel[3] = 255
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])

    let frameRate: Int32 = 30
    for frame in 0..<Int(seconds * Double(frameRate)) {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(for: .milliseconds(5))
        }
        adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate))
    }
    input.markAsFinished()
    await writer.finishWriting()
    if let error = writer.error {
        throw error
    }
}
