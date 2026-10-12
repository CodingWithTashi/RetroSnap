import Foundation
import ImageIO
import Testing
@testable import Retrosnap

@MainActor
final class PhotoLibraryFolderTests {
    private let folder = PhotoLibraryFolder(
        url: FileManager.default.temporaryDirectory.appendingPathComponent("PhotoLibraryFolderTests-\(UUID().uuidString)")
    )

    deinit {
        try? FileManager.default.removeItem(at: folder.url)
    }

    private func contents() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.url.path)) ?? []).sorted()
    }

    @Test func aShotIsFiledExactlyAsItWasCaptured() throws {
        let original = makeJPEG(width: 1200, height: 1600)
        let image = try folder.store(original: original, id: "A1", fileExtension: "heic")

        #expect(image == .file(full: "A1.heic", thumbnail: "A1-thumb.jpg"))
        #expect(contents() == ["A1-thumb.jpg", "A1.heic"])
        #expect(try Data(contentsOf: folder.url(for: "A1.heic")) == original)
    }

    @Test func theThumbnailIsASmallCopyForTheGrid() throws {
        try folder.store(original: makeJPEG(width: 1200, height: 1600), id: "A1", fileExtension: "jpg")
        let thumbnail = try #require(describe(try Data(contentsOf: folder.url(for: "A1-thumb.jpg"))))
        #expect(thumbnail.height == PhotoLibraryFolder.thumbnailPixelSize)
        #expect(thumbnail.width == PhotoLibraryFolder.thumbnailPixelSize * 3 / 4)
    }

    @Test func aSidewaysShotGetsAnUprightThumbnail() throws {
        try folder.store(original: makeJPEG(width: 1600, height: 1200, orientation: .right), id: "A1", fileExtension: "jpg")
        let thumbnail = try #require(describe(try Data(contentsOf: folder.url(for: "A1-thumb.jpg"))))
        #expect(thumbnail.width < thumbnail.height)
    }

    // MARK: Clips

    private func recording(isPortrait: Bool = false) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        try await makeMovie(at: url, isPortrait: isPortrait)
        return url
    }

    @Test func aClipIsFiledWithAPosterAndAThumbnail() async throws {
        let movie = try await recording()
        let clip = try await folder.storeClip(movieAt: movie, id: "V1")

        #expect(clip.poster == .file(full: "V1.jpg", thumbnail: "V1-thumb.jpg"))
        #expect(clip.videoFile == "V1.mov")
        #expect(contents() == ["V1-thumb.jpg", "V1.jpg", "V1.mov"])
        #expect(!FileManager.default.fileExists(atPath: movie.path))

        let poster = try #require(describe(try Data(contentsOf: folder.url(for: "V1.jpg"))))
        #expect(poster.width == 320)
        #expect(poster.height == 240)
    }

    @Test func aPortraitClipGetsAnUprightPoster() async throws {
        let movie = try await recording(isPortrait: true)
        try await folder.storeClip(movieAt: movie, id: "V1")
        let poster = try #require(describe(try Data(contentsOf: folder.url(for: "V1.jpg"))))
        #expect(poster.width == 240)
        #expect(poster.height == 320)
    }

    @Test func aFileThatIsNotAMovieIsRefusedAndLeavesNothingBehind() async throws {
        let junk = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        try Data("not a movie".utf8).write(to: junk)
        await #expect(throws: (any Error).self) {
            try await folder.storeClip(movieAt: junk, id: "V1")
        }
        #expect(contents().isEmpty)
    }

    @Test func dataThatIsNotAPictureIsRefusedAndLeavesNothingBehind() {
        #expect(throws: (any Error).self) {
            try folder.store(original: Data("not a picture".utf8), id: "A1", fileExtension: "heic")
        }
        #expect(contents().isEmpty)
    }
}
