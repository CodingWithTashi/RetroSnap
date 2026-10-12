#if DEBUG
import Foundation

/// The stand-in pictures the mocks and the design boards use.
extension PhotoImage {
    /// One of the 3:4 stock photos, by its picsum id.
    static func photo(_ id: Int) -> PhotoImage {
        .sample(.photo(id))
    }

    /// What the mock camera sees through each lens.
    static let sceneBack = PhotoImage.sample(SampleImage(full: "scene-back", thumbnail: "scene-back-thumb"))
    static let sceneFront = PhotoImage.sample(SampleImage(full: "scene-front", thumbnail: "scene-front-thumb"))
}
#endif
