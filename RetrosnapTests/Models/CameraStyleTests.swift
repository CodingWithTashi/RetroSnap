import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct CameraStyleTests {
    @Test func onlyTheMiniPrintIsAnInstantPrint() {
        #expect(CameraStyle.allCases.filter(\.isInstantPrint) == [.instant, .instSquare])
    }

    @Test func theDefaultCameraIsTheFilm() {
        #expect(CameraStyle.default == .film)
    }

    @Test func aCardReadsItsNameAndSummary() {
        let label = "D Classic. True, gently warm colour and a red date in the corner. The everyday 35mm point-and-shoot."
        #expect(CameraStyle.film.cardAccessibilityLabel(isSelected: false) == label)
        #expect(CameraStyle.film.cardAccessibilityLabel(isSelected: true).hasSuffix("point-and-shoot. Selected."))
    }

    @Test func theCameraShapeIsThreeByFour() {
        #expect(Photo.cameraAspect == 0.75)
        #expect(PixelSize(width: 0, height: 0).aspectRatio == Photo.cameraAspect)
    }
}
