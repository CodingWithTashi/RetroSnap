import Foundation

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
