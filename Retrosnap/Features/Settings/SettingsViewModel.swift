import Foundation
import Observation

nonisolated enum SettingsToggle: Hashable, Sendable {
    case saveToPhotos
    case shutterSound
    case haptics
}

nonisolated struct SettingsRow: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case toggle(SettingsToggle)
        /// A row that leads somewhere, with an optional current value.
        case link(value: String)
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
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter

    init(settings: any SettingsStoring, storage: any StorageMonitoring, router: AppRouter, toasts: ToastCenter) {
        self.settings = settings
        self.storage = storage
        self.router = router
        self.toasts = toasts
    }

    var groups: [[SettingsRow]] {
        [
            [
                SettingsRow(label: "Save to Photos", kind: .toggle(.saveToPhotos)),
                SettingsRow(label: "Video quality", kind: .link(value: settings.videoQuality)),
            ],
            [
                SettingsRow(label: "Shutter sound", kind: .toggle(.shutterSound)),
                SettingsRow(label: "Haptics", kind: .toggle(.haptics)),
            ],
            [SettingsRow(label: "Storage", kind: .link(value: storage.usedText))],
            [
                SettingsRow(label: "Privacy", kind: .link(value: "")),
                SettingsRow(label: "Help", kind: .link(value: "")),
                SettingsRow(label: "About", kind: .link(value: settings.versionText)),
            ],
        ]
    }

    func isOn(_ toggle: SettingsToggle) -> Bool {
        switch toggle {
        case .saveToPhotos: settings.saveToPhotos
        case .shutterSound: settings.shutterSound
        case .haptics: settings.haptics
        }
    }

    func toggle(_ toggle: SettingsToggle) {
        switch toggle {
        case .saveToPhotos: settings.saveToPhotos.toggle()
        case .shutterSound: settings.shutterSound.toggle()
        case .haptics: settings.haptics.toggle()
        }
    }

    /// These rows have nowhere to go yet; as in the design, they name themselves in a toast.
    func linkTapped(_ label: String) {
        toasts.show(label)
    }

    func backTapped() {
        router.back()
    }
}
