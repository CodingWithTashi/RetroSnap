import Foundation
import Observation

nonisolated struct Toast: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let actionTitle: String?
}

/// The one toast the app shows at a time. Lives above the navigation stack so it survives screen changes,
/// e.g. "Photo deleted · Undo" appears after the viewer has already closed.
@Observable
final class ToastCenter {
    static let displayDuration = Duration.milliseconds(2800)

    private(set) var current: Toast?

    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private var action: (@MainActor () -> Void)?
    @ObservationIgnored private var dismissal: (any ScheduledWork)?
    @ObservationIgnored private var nextID = 0

    init(scheduler: any Scheduling) {
        self.scheduler = scheduler
    }

    /// Shows a toast, replacing any current one and restarting the clock.
    func show(_ text: String, actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        dismissal?.cancel()
        nextID += 1
        current = Toast(id: nextID, text: text, actionTitle: actionTitle)
        self.action = action
        dismissal = scheduler.after(Self.displayDuration) { [weak self] in
            self?.dismiss()
        }
    }

    /// Runs the toast's action (Undo) and clears it.
    func performAction() {
        let action = action
        dismiss()
        action?()
    }

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        action = nil
        current = nil
    }
}
