import Observation
import UIKit

/// AirPrint. The first job asks which printer to use; later ones go straight to it.
@Observable
final class AirPrinter: NSObject, PhotoPrinting, UIPrintInteractionControllerDelegate {
    let paperName = "Photo paper"

    @ObservationIgnored private let exporter: any PhotoExporting
    @ObservationIgnored private let settings: any SettingsStoring
    /// The size of the job being sent, for picking the printer's closest paper.
    @ObservationIgnored private var pageSize = PrintSize.fourBySix.pageSize

    init(exporter: any PhotoExporting, settings: any SettingsStoring) {
        self.exporter = exporter
        self.settings = settings
    }

    var printerName: String? {
        settings.printer?.name
    }

    func print(_ job: PrintJob, completion: @escaping @MainActor (PrintOutcome) -> Void) {
        guard let printer = settings.printer else {
            pickPrinter { [weak self] didPick in
                guard let self, didPick else {
                    completion(.cancelled)
                    return
                }
                print(job, completion: completion)
            }
            return
        }
        exporter.exportPrint(job) { [weak self] file in
            guard let self, let file else {
                completion(.failed)
                return
            }
            let info = UIPrintInfo.printInfo()
            info.outputType = .photo
            info.jobName = "RetroSnap"
            pageSize = job.size.pageSize

            let controller = UIPrintInteractionController.shared
            controller.printInfo = info
            controller.delegate = self
            // One page per copy: a job sent without the system's sheet has no copies setting.
            controller.printingItems = Array(repeating: file, count: job.copies)
            controller.print(to: UIPrinter(url: printer.url)) { _, isCompleted, error in
                try? FileManager.default.removeItem(at: file)
                completion(isCompleted && error == nil ? .sent : .failed)
            }
        }
    }

    func choosePrinter() {
        pickPrinter { _ in }
    }

    /// Shows the system's printer list and keeps the choice.
    private func pickPrinter(_ completion: @escaping @MainActor (Bool) -> Void) {
        guard let presenter = UIApplication.shared.topViewController else {
            completion(false)
            return
        }
        let picker = UIPrinterPickerController(initiallySelectedPrinter: settings.printer.map { UIPrinter(url: $0.url) })
        let finish: UIPrinterPickerController.CompletionHandler = { [weak self] picker, didSelect, _ in
            if didSelect, let printer = picker.selectedPrinter {
                self?.settings.printer = SavedPrinter(name: printer.displayName, url: printer.url)
            }
            completion(didSelect)
        }
        // An iPad shows the list as a popover, which needs somewhere to point.
        if presenter.traitCollection.userInterfaceIdiom == .pad {
            let anchor = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            picker.present(from: anchor, in: presenter.view, animated: true, completionHandler: finish)
        } else {
            picker.present(animated: true, completionHandler: finish)
        }
    }

    // MARK: UIPrintInteractionControllerDelegate

    func printInteractionController(
        _ printInteractionController: UIPrintInteractionController, choosePaper paperList: [UIPrintPaper]
    ) -> UIPrintPaper {
        UIPrintPaper.bestPaper(forPageSize: pageSize, withPapersFrom: paperList)
    }
}
