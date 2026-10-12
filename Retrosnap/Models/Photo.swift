import Foundation

/// A shot in the library: a still, or a clip when it has a duration.
nonisolated struct Photo: Identifiable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var image: PhotoImage
    var camera: CameraStyle
    var capturedAt: Date
    /// Taken in this session; shown as "Just now" instead of its day.
    var isJustCaptured = false
    /// Length in seconds for a video, nil for a photo.
    var videoSeconds: Int?
    /// The clip's movie, by file name inside the library folder. `image` is its first frame.
    var videoFile: String?
    var adjustments = PhotoAdjustments.neutral
    /// Set only while "Location on photos" is on.
    var location: PhotoLocation?
    /// A saved collage: already a finished picture, so it is shown as it is and named as a collage.
    var isCollage = false

    var isVideo: Bool {
        videoSeconds != nil
    }

    /// The library files this shot owns.
    var fileNames: [String] {
        image.fileNames + (videoFile.map { [$0] } ?? [])
    }

    /// Clip length as shown on thumbnails: "0:12".
    var videoDurationText: String? {
        videoSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
    }
}

extension Photo: Codable {
    /// Everything the library keeps. "Just now" belongs to the session and is left out.
    private enum CodingKeys: String, CodingKey {
        case id, image, camera, capturedAt, videoSeconds, videoFile, adjustments, location, isCollage
    }

    /// Fields added after the first saved libraries are optional when reading one back.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(ID.self, forKey: .id)
        image = try values.decode(PhotoImage.self, forKey: .image)
        camera = try values.decode(CameraStyle.self, forKey: .camera)
        capturedAt = try values.decode(Date.self, forKey: .capturedAt)
        videoSeconds = try values.decodeIfPresent(Int.self, forKey: .videoSeconds)
        videoFile = try values.decodeIfPresent(String.self, forKey: .videoFile)
        adjustments = try values.decode(PhotoAdjustments.self, forKey: .adjustments)
        location = try values.decodeIfPresent(PhotoLocation.self, forKey: .location)
        isCollage = try values.decodeIfPresent(Bool.self, forKey: .isCollage) ?? false
    }
}
