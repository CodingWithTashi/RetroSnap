import Foundation

/// Turns a library photo into a finished picture, with its look, stamp and edits drawn in, and sends it out of the app.
protocol PhotoExporting: AnyObject {
    /// Bakes the photo or clip and adds it to the Photos library. The completion says whether it got there.
    func saveToPhotos(_ photo: Photo, completion: @escaping @MainActor (Bool) -> Void)
    /// Bakes the photo or clip into a file in the temporary folder, for sharing or printing.
    /// The completion gets the file, or nil when the shot cannot be baked.
    func export(_ photo: Photo, completion: @escaping @MainActor (URL?) -> Void)
    /// Bakes a print: the photo on white paper in the job's size, inside its border when it has one.
    func exportPrint(_ job: PrintJob, completion: @escaping @MainActor (URL?) -> Void)
    /// Bakes a collage into one picture and files it in the library.
    /// The completion gets its record, or nil when it could not be made.
    func makeCollage(_ collage: Collage, completion: @escaping @MainActor (Photo?) -> Void)
    /// Bakes a collage into a file in the temporary folder, for sharing without saving it.
    func exportCollage(_ collage: Collage, completion: @escaping @MainActor (URL?) -> Void)
    /// How far along each clip being baked is, from 0 to 1. Photos bake too fast to appear here.
    var progress: [Photo.ID: Double] { get }
}

/// What view models call when a shot is ready. It reaches the Photos library only while "Save to Photos"
/// is on and the user has allowed adding to it.
final class PhotosSaver {
    private let exporter: any PhotoExporting
    private let permissions: any PermissionServicing
    private let settings: any SettingsStoring
    private let toasts: ToastCenter

    init(
        exporter: any PhotoExporting, permissions: any PermissionServicing, settings: any SettingsStoring,
        toasts: ToastCenter
    ) {
        self.exporter = exporter
        self.permissions = permissions
        self.settings = settings
        self.toasts = toasts
    }

    /// New shots are also going to the Photos library.
    var isSaving: Bool {
        settings.saveToPhotos && permissions.photoLibraryAccess == .granted
    }

    /// The confirmation shown after a shot: where it went.
    var savedText: String {
        isSaving ? "Saved to Photos" : "Saved in RetroSnap"
    }

    /// How far along a clip's bake is, or nil when nothing is being baked for it.
    func progress(for id: Photo.ID) -> Double? {
        exporter.progress[id]
    }

    /// The shot is in the app's own library either way; if Photos does not take it, that is said.
    func save(_ photo: Photo) {
        guard isSaving else { return }
        exporter.saveToPhotos(photo) { [toasts] isSaved in
            if !isSaved {
                toasts.show("Couldn’t save to Photos")
            }
        }
    }
}
