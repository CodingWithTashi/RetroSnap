import Foundation
import Observation

/// Five sliders, one at a time, over a draft that is saved on Done and dropped on Cancel.
@Observable
final class EditViewModel {
    let photoID: Photo.ID
    private(set) var draft: PhotoAdjustments
    private(set) var tool: EditTool
    /// The photo is being held down to show the original.
    private(set) var isComparing = false

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        router: AppRouter,
        toasts: ToastCenter,
        dayLabeler: DayLabeler,
        tool: EditTool = .effect,
        preset: PhotoAdjustments? = nil
    ) {
        self.photoID = photoID
        self.photos = photos
        self.router = router
        self.toasts = toasts
        self.dayLabeler = dayLabeler
        self.tool = tool
        draft = preset ?? photos.photo(id: photoID)?.adjustments ?? .neutral
    }

    var photo: Photo? {
        photos.photo(id: photoID)
    }

    var isInstant: Bool {
        photo?.camera == .instant
    }

    /// The preview's box: width over height.
    var displayAspect: CGFloat {
        photo?.displayAspect ?? 3.0 / 4.0
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.capturedAt) }
    }

    /// What the preview draws: the draft, or the untouched photo while comparing.
    var displayed: PhotoAdjustments {
        isComparing ? .original : draft
    }

    var value: Int {
        draft[keyPath: tool.keyPath]
    }

    var valueText: String {
        (tool.isBipolar && value > 0 ? "+" : "") + "\(value)"
    }

    var sliderValue: Double {
        get { Double(value) }
        set {
            let range = tool.range
            draft[keyPath: tool.keyPath] = min(range.upperBound, max(range.lowerBound, Int(newValue.rounded())))
        }
    }

    func select(_ newTool: EditTool) {
        tool = newTool
    }

    func compareBegan() {
        isComparing = true
    }

    func compareEnded() {
        isComparing = false
    }

    func resetTapped() {
        draft = .neutral
    }

    func cancelTapped() {
        router.back()
    }

    func doneTapped() {
        photos.setAdjustments(draft, for: photoID)
        router.back()
        toasts.show("Edits saved")
    }
}
