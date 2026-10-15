import Foundation
import Observation

nonisolated enum SettingsToggle: Hashable, Sendable {
    case saveToPhotos
    case locationOnPhotos
    case shutterSound
    case haptics
}

nonisolated struct SettingsRow: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case toggle(SettingsToggle)
        /// A fact to read: nothing happens when it is tapped.
        case value(String)
        /// A row that leaves the app for a web page or a new email.
        case link(URL)
    }

    let label: String
    let kind: Kind

    var id: String { label }
}

@Observable
final class SettingsViewModel {
    let footer = "Free forever. No accounts, no ads.\nYour photos never leave your phone."

    @ObservationIgnored private let settings: any SettingsStoring
    @ObservationIgnored private let storage: any StorageMonitoring
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let permissions: any PermissionServicing
    @ObservationIgnored private let saver: PhotosSaver
    @ObservationIgnored private let links: AppLinks
    @ObservationIgnored private let openLink: @MainActor (URL, @escaping @MainActor (Bool) -> Void) -> Void
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter

    /// - Parameter openLink: Hands a web or mail address to the app that opens it, then says whether one did.
    init(
        settings: any SettingsStoring,
        storage: any StorageMonitoring,
        location: any LocationProviding,
        permissions: any PermissionServicing,
        saver: PhotosSaver,
        links: AppLinks,
        openLink: @escaping @MainActor (URL, @escaping @MainActor (Bool) -> Void) -> Void,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.settings = settings
        self.storage = storage
        self.location = location
        self.permissions = permissions
        self.saver = saver
        self.links = links
        self.openLink = openLink
        self.router = router
        self.toasts = toasts
    }

    /// The screen is on show: measure the storage it lists.
    func appeared() {
        storage.refresh()
    }

    var groups: [[SettingsRow]] {
        [
            [
                SettingsRow(label: "Save to Photos", kind: .toggle(.saveToPhotos)),
                SettingsRow(label: "Location on photos", kind: .toggle(.locationOnPhotos)),
                SettingsRow(label: "Video quality", kind: .value(settings.videoQuality)),
            ],
            [
                SettingsRow(label: "Shutter sound", kind: .toggle(.shutterSound)),
                SettingsRow(label: "Haptics", kind: .toggle(.haptics)),
            ],
            [SettingsRow(label: "Storage", kind: .value(storage.usedText))],
            // Privacy and Help are there only when they have somewhere to lead.
            [
                links.privacyPolicy.map { SettingsRow(label: "Privacy", kind: .link($0)) },
                links.support.map { SettingsRow(label: "Help", kind: .link($0)) },
                SettingsRow(label: "About", kind: .value(settings.versionText)),
            ].compactMap { $0 },
        ]
    }

    func isOn(_ toggle: SettingsToggle) -> Bool {
        switch toggle {
        // Both are on only while iOS allows them: access can be missing, or taken away in Settings.
        case .saveToPhotos: saver.isSaving
        case .locationOnPhotos: settings.locationOnPhotos && location.isAllowed
        case .shutterSound: settings.shutterSound
        case .haptics: settings.haptics
        }
    }

    func toggle(_ toggle: SettingsToggle) {
        switch toggle {
        case .saveToPhotos: toggleSaving()
        case .locationOnPhotos: toggleLocation()
        case .shutterSound: settings.shutterSound.toggle()
        case .haptics: settings.haptics.toggle()
        }
    }

    /// Turning saving on asks for Photos access when it is still missing.
    private func toggleSaving() {
        guard !isOn(.saveToPhotos) else {
            settings.saveToPhotos = false
            return
        }
        settings.saveToPhotos = true
        if permissions.photoLibraryAccess != .granted {
            permissions.requestPhotoLibraryAccess {}
        }
    }

    /// Turning location on asks iOS first. A refusal leaves it off and points to Settings, where it can be changed.
    private func toggleLocation() {
        guard !isOn(.locationOnPhotos) else {
            settings.locationOnPhotos = false
            return
        }
        location.requestAccess { [weak self] isAllowed in
            guard let self else { return }
            settings.locationOnPhotos = isAllowed
            if !isAllowed {
                toasts.show("Location access is off", actionTitle: "Settings") { [permissions] in
                    permissions.openSettings()
                }
            }
        }
    }

    func linkTapped(_ url: URL) {
        openLink(url) { [toasts] isOpened in
            guard !isOpened else { return }
            // A phone with no mail app set up cannot start an email, so the address is shown to write to.
            let address = url.scheme == "mailto" ? URLComponents(url: url, resolvingAgainstBaseURL: false)?.path : nil
            toasts.show(address.map { "Write to \($0)" } ?? "Couldn’t open the page")
        }
    }

    func backTapped() {
        router.back()
    }
}
