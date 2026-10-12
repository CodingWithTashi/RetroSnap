import Foundation

/// The 13 photos the prototype starts with: four today, five yesterday, four a week ago.
enum SeedData {
    static func photos(clock: any DateProviding) -> [Photo] {
        let seed: [(id: String, picture: Int, camera: CameraStyle, daysAgo: Int)] = [
            ("s1", 1011, .film, 0), ("s2", 237, .disposable, 0), ("s3", 1027, .instant, 0), ("s4", 1039, .camcorder, 0),
            ("s5", 1016, .film, 1), ("s6", 1025, .disposable, 1), ("s7", 29, .digicam, 1), ("s8", 1043, .instant, 1),
            ("s9", 1080, .film, 1),
            ("s10", 1074, .camcorder, 7), ("s11", 42, .film, 7), ("s12", 1069, .digicam, 7), ("s13", 110, .instant, 7),
        ]
        return seed.map { item in
            Photo(
                id: item.id,
                image: .photo(item.picture),
                camera: item.camera,
                capturedAt: clock.calendar.date(byAdding: .day, value: -item.daysAgo, to: clock.now) ?? clock.now
            )
        }
    }

    /// The clip shown on the "Video result" board.
    static func sampleVideo(clock: any DateProviding) -> Photo {
        Photo(id: "s1", image: .photo(1039), camera: .camcorder, capturedAt: clock.now, videoSeconds: 24)
    }
}
