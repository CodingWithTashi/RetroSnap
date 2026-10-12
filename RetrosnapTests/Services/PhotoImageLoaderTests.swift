import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Retrosnap

@MainActor
final class PhotoImageLoaderTests {
    private let folder = PhotoLibraryFolder(
        url: FileManager.default.temporaryDirectory.appendingPathComponent("PhotoImageLoaderTests-\(UUID().uuidString)")
    )

    init() throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder.url)
    }

    private func writeJPEG(_ name: String, width: Int, height: Int, orientation: CGImagePropertyOrientation = .up) throws {
        try makeJPEG(width: width, height: height, orientation: orientation).write(to: folder.url(for: name))
    }

    @Test func decodesAFileFromTheLibrary() async throws {
        try writeJPEG("a-thumb.jpg", width: 300, height: 400)
        let image = try #require(await PhotoImageLoader(folder: folder).image(named: "a-thumb.jpg"))
        #expect(image.width == 300)
        #expect(image.height == 400)
    }

    @Test func aPhotoBiggerThanAScreenIsScaledDown() async throws {
        try writeJPEG("a.jpg", width: 3000, height: 4000)
        let image = try #require(await PhotoImageLoader(folder: folder).image(named: "a.jpg"))
        #expect(image.height == PhotoImageLoader.maxPixelSize)
        #expect(image.width == PhotoImageLoader.maxPixelSize * 3 / 4)
    }

    @Test func aPhotoShotSidewaysComesOutUpright() async throws {
        try writeJPEG("a.jpg", width: 400, height: 300, orientation: .right)
        let image = try #require(await PhotoImageLoader(folder: folder).image(named: "a.jpg"))
        #expect(image.width == 300)
        #expect(image.height == 400)
    }

    @Test func aDecodedPhotoIsKeptForTheNextDraw() async throws {
        try writeJPEG("a.jpg", width: 30, height: 40)
        let loader = PhotoImageLoader(folder: folder)
        #expect(loader.cached("a.jpg") == nil)
        let image = await loader.image(named: "a.jpg")
        #expect(image != nil)
        #expect(loader.cached("a.jpg") === image)
    }

    @Test func aMissingFileGivesNoPicture() async {
        let loader = PhotoImageLoader(folder: folder)
        #expect(await loader.image(named: "nope.jpg") == nil)
        #expect(loader.cached("nope.jpg") == nil)
    }
}
