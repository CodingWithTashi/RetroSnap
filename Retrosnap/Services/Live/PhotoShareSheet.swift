import UIKit

/// The system share sheet, fed with the baked file of a photo or clip.
final class PhotoShareSheet: PhotoSharing {
    private let exporter: any PhotoExporting
    private let toasts: ToastCenter

    init(exporter: any PhotoExporting, toasts: ToastCenter) {
        self.exporter = exporter
        self.toasts = toasts
    }

    func share(_ photo: Photo) {
        // A clip takes a moment to bake; a photo is ready before a message could be read.
        let preparing = photo.isVideo ? toasts.show("Preparing video…") : nil
        exporter.export(photo) { [weak self] file in
            // Only this sheet's own message is cleared: another toast may have taken its place meanwhile.
            if file != nil, let preparing {
                self?.toasts.dismiss(preparing)
            }
            self?.present(file)
        }
    }

    func share(_ collage: Collage) {
        exporter.exportCollage(collage) { [weak self] file in
            self?.present(file)
        }
    }

    /// Opens the sheet for a baked file, and removes the file once the sheet is done with it.
    private func present(_ file: URL?) {
        guard let file, let presenter = UIApplication.shared.topViewController else {
            toasts.show("Couldn’t share this")
            return
        }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: file)
        }
        // An iPad shows the sheet as a popover, which needs somewhere to point: the action row.
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 80, width: 1, height: 1
        )
        presenter.present(sheet, animated: true)
    }
}
