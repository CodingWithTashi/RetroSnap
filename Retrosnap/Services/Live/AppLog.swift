import os

extension Logger {
    /// The app's log, one category for each part that writes to it.
    nonisolated static func retroSnap(_ category: String) -> Logger {
        Logger(subsystem: "com.retrosnap.vintagecamera", category: category)
    }
}
