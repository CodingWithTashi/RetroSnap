import CoreGraphics
import Foundation
import Observation

/// Collage in three steps on one screen: choose a layout, choose its photos, arrange them.
@Observable
final class CollageViewModel {
    private(set) var step: CollageStep
    private(set) var template = CollageTemplate.feature
    /// Picked photos in pick order, which is also their cell order.
    private(set) var pickedIDs: [Photo.ID]
    /// The cell tapped first while swapping.
    private(set) var swapSelection: Int?
    private(set) var border = CollageBorder.cream

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let feedback: FeedbackCenter

    /// - Parameter startStep: Opens straight on a later step, for the design's Arrange board.
    init(
        seedID: Photo.ID?,
        photos: any PhotoStoring,
        router: AppRouter,
        toasts: ToastCenter,
        feedback: FeedbackCenter,
        startStep: Int = 1
    ) {
        self.photos = photos
        self.router = router
        self.toasts = toasts
        self.feedback = feedback
        let start = CollageStep(rawValue: startStep) ?? .layout
        step = start
        if start != .layout {
            pickedIDs = ["s1", "s3", "s2"].filter { photos.photo(id: $0) != nil }
        } else if let seed = seedID.flatMap(photos.photo(id:)), !seed.isVideo {
            // The photo you came from is already chosen. Clips cannot go in a collage.
            pickedIDs = [seed.id]
        } else {
            pickedIDs = []
        }
    }

    // MARK: Header and button

    var title: String {
        switch step {
        case .layout: "Choose a layout"
        case .pick: "Choose \(template.photoCount) photos"
        case .arrange: "Arrange"
        }
    }

    var subtitle: String {
        "Step \(step.rawValue) of 3"
    }

    private var hasEnoughPhotos: Bool {
        pickedIDs.count == template.photoCount
    }

    var actionTitle: String {
        switch step {
        case .layout: "Choose \(template.photoCount) photos"
        case .pick: hasEnoughPhotos ? "Next" : "\(pickedIDs.count) of \(template.photoCount) selected"
        case .arrange: "Save collage"
        }
    }

    var isActionEnabled: Bool {
        step != .pick || hasEnoughPhotos
    }

    // MARK: Step 1

    func select(_ newTemplate: CollageTemplate) {
        template = newTemplate
        pickedIDs = Array(pickedIDs.prefix(newTemplate.photoCount))
    }

    // MARK: Step 2

    /// Stills only.
    var candidates: [Photo] {
        photos.photos.filter { !$0.isVideo }
    }

    /// 1-based position of a picked photo, nil if it is not picked.
    func pickNumber(for id: Photo.ID) -> Int? {
        pickedIDs.firstIndex(of: id).map { $0 + 1 }
    }

    func togglePick(_ id: Photo.ID) {
        if let index = pickedIDs.firstIndex(of: id) {
            pickedIDs.remove(at: index)
        } else if pickedIDs.count < template.photoCount {
            pickedIDs.append(id)
        }
    }

    // MARK: Step 3

    var arrangedPhotos: [Photo] {
        pickedIDs.compactMap(photos.photo(id:))
    }

    var hint: String {
        swapSelection == nil ? "Tap two photos to swap them" : "Now tap where it should go"
    }

    /// The first tap marks a photo, the second swaps the two.
    func cellTapped(_ index: Int) {
        guard pickedIDs.indices.contains(index) else { return }
        guard let first = swapSelection else {
            swapSelection = index
            return
        }
        pickedIDs.swapAt(first, index)
        swapSelection = nil
        feedback.haptic(.soft)
    }

    func select(_ newBorder: CollageBorder) {
        border = newBorder
    }

    var frameSize: CGSize {
        template == .strip ? CGSize(width: 170, height: 170 * 2.7) : CGSize(width: 300, height: 400)
    }

    /// Border thickness around the whole collage.
    var frameInset: CGFloat {
        border == .none ? 0 : 10
    }

    /// Half the gutter between photos.
    var cellGap: CGFloat {
        border == .none ? 0 : 4
    }

    func shareTapped() {
        toasts.show("Share sheet opens here")
    }

    // MARK: Moving between steps

    func actionTapped() {
        switch step {
        case .layout:
            step = .pick
        case .pick:
            guard hasEnoughPhotos else { return }
            swapSelection = nil
            step = .arrange
        case .arrange:
            feedback.haptic(.firm)
            router.returnToGallery()
            toasts.show("Collage saved to Photos")
        }
    }

    func backTapped() {
        switch step {
        case .layout:
            router.back()
        case .pick:
            step = .layout
        case .arrange:
            swapSelection = nil
            step = .pick
        }
    }
}
