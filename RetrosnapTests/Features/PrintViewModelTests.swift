import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct PrintViewModelTests {
    private let world = TestWorld(path: [.result("s1"), .print("s1")])

    private func make(printing: (any PhotoPrinting)? = nil) -> PrintViewModel {
        PrintViewModel(
            photoID: "s1", photos: world.photos, printing: printing ?? world.printing, router: world.router,
            toasts: world.toasts, feedback: world.feedback, dayLabeler: world.dayLabeler
        )
    }

    @Test func defaultsAreOneBorderedFourBySix() {
        let vm = make()
        #expect(vm.size == .fourBySix)
        #expect(vm.copies == 1)
        #expect(vm.hasBorder)
        #expect(!vm.isMoreExpanded)
        #expect(vm.actionTitle == "Print")
        #expect(vm.paperSize == CGSize(width: 240, height: 360))
        #expect(vm.paperPadding == 14)
    }

    @Test func previewAndCopiesDescribeThemselvesForVoiceOver() {
        let vm = make()
        #expect(vm.previewLabel == "Print preview, 4×6")
        #expect(vm.copiesLabel == "1 copies")
        vm.increaseCopies()
        #expect(vm.copiesLabel == "2 copies")
    }

    @Test func sizesMatchTheDesign() {
        #expect(PrintSize.allCases.map(\.label) == ["4×6", "Square", "Strip"])
        let vm = make()
        vm.select(.square)
        #expect(vm.paperSize == CGSize(width: 290, height: 290))
        #expect(vm.paperPadding == 14)
        vm.select(.strip)
        #expect(vm.paperSize == CGSize(width: 130, height: 330))
        #expect(vm.paperPadding == 8)
    }

    @Test func turningTheBorderOffRemovesThePadding() {
        let vm = make()
        vm.toggleBorder()
        #expect(!vm.hasBorder)
        #expect(vm.paperPadding == 0)
        vm.toggleBorder()
        #expect(vm.paperPadding == 14)
    }

    @Test func copiesStayBetweenOneAndTwenty() {
        let vm = make()
        vm.decreaseCopies()
        #expect(vm.copies == 1)
        for _ in 0..<30 { vm.increaseCopies() }
        #expect(vm.copies == 20)
        vm.decreaseCopies()
        #expect(vm.copies == 19)
    }

    @Test func buttonNamesTheNumberOfCopies() {
        let vm = make()
        vm.increaseCopies()
        #expect(vm.actionTitle == "Print 2 copies")
        vm.decreaseCopies()
        #expect(vm.actionTitle == "Print")
    }

    @Test func moreOptionsExpandAndCollapse() {
        let vm = make()
        vm.toggleMore()
        #expect(vm.isMoreExpanded)
        #expect(vm.printerName == "Living Room Printer")
        #expect(vm.paperName == "Glossy photo")
        vm.toggleMore()
        #expect(!vm.isMoreExpanded)
    }

    @Test func cancelGoesBackQuietly() {
        make().cancelTapped()
        #expect(world.router.path == [.result("s1")])
        #expect(world.toasts.current == nil)
    }

    @Test func printGoesBackAndConfirms() {
        make().printTapped()
        #expect(world.router.path == [.result("s1")])
        #expect(world.toasts.current?.text == "Sent to Living Room Printer")
        #expect(world.feedbackSpy.haptics == [.firm])
    }

    // MARK: A real printer

    @Test func theJobCarriesThePhotoWithItsSizeBorderAndCopies() throws {
        let printer = PrintSpy()
        let vm = make(printing: printer)
        vm.select(.square)
        vm.toggleBorder()
        vm.increaseCopies()
        vm.increaseCopies()
        vm.printTapped()
        let job = try #require(printer.jobs.first)
        #expect(job.photo.id == "s1")
        #expect(job.size == .square)
        #expect(!job.hasBorder)
        #expect(job.copies == 3)
    }

    @Test func theScreenStaysUntilTheJobHasGoneOut() {
        let printer = PrintSpy()
        let vm = make(printing: printer)
        vm.printTapped()
        #expect(world.router.path == [.result("s1"), .print("s1")])
        #expect(world.toasts.current == nil)
        #expect(world.feedbackSpy.haptics == [.firm])

        printer.finish(.sent)
        #expect(world.router.path == [.result("s1")])
        #expect(world.toasts.current?.text == "Sent to Office Printer")
    }

    @Test func aSecondTapWhileTheJobIsGoingOutIsIgnored() {
        let printer = PrintSpy()
        let vm = make(printing: printer)
        vm.printTapped()
        vm.printTapped()
        #expect(printer.jobs.count == 1)

        printer.finish(.cancelled)
        vm.printTapped()
        #expect(printer.jobs.count == 2)
    }

    @Test func backingOutOfChoosingAPrinterChangesNothing() {
        let printer = PrintSpy(printerName: nil)
        let vm = make(printing: printer)
        vm.printTapped()
        printer.finish(.cancelled)
        #expect(world.router.path == [.result("s1"), .print("s1")])
        #expect(world.toasts.current == nil)
    }

    @Test func aJobThatCouldNotBeSentSaysSoAndStaysOnTheScreen() {
        let printer = PrintSpy()
        let vm = make(printing: printer)
        vm.printTapped()
        printer.finish(.failed)
        #expect(world.router.path == [.result("s1"), .print("s1")])
        #expect(world.toasts.current?.text == "Couldn’t reach the printer")
    }

    @Test func thePrinterRowSaysWhenNoneIsChosenAndLetsOneBePicked() {
        let printer = PrintSpy(printerName: nil)
        let vm = make(printing: printer)
        #expect(vm.printerName == "Not chosen yet")
        #expect(vm.paperName == "Photo paper")

        vm.printerTapped()
        #expect(printer.choosePrinterCount == 1)
        printer.printerName = "Office Printer"
        #expect(vm.printerName == "Office Printer")
    }

    @Test func aJobSentBeforeAnyPrinterHadANameStillConfirms() {
        let printer = PrintSpy(printerName: nil)
        let vm = make(printing: printer)
        vm.printTapped()
        printer.finish(.sent)
        #expect(world.toasts.current?.text == "Sent to the printer")
    }
}
