import Testing
@testable import Retrosnap

extension CameraViewModelTests {
    /// The zoom button and the pinch.
    @MainActor
    struct Zoom: CameraViewModelSuite {
        let world = TestWorld()

        // MARK: Zoom

        @Test func theCameraOpensOnTheMainLens() {
            let vm = returning()
            #expect(vm.zoomTitle == "1×")
            #expect(vm.zoomLabel == "Zoom: 1×")
            #expect(!vm.isZoomed)
            #expect(vm.isZoomVisible)
            #expect(vm.sceneMagnification == 1)
        }

        @Test func theZoomButtonStepsThroughTheLensesAndRoundAgain() {
            let camera = CameraSpy()
            let vm = returning(camera: camera)
            vm.zoomTapped()
            #expect(vm.zoomTitle == "2×")
            #expect(vm.isZoomed)
            vm.zoomTapped()
            #expect(vm.zoomTitle == "0.5×")
            #expect(vm.isZoomed)
            vm.zoomTapped()
            #expect(vm.zoomTitle == "1×")
            #expect(!vm.isZoomed)
            #expect(camera.zooms == [
                .init(factor: 2, smoothly: true), .init(factor: 0.5, smoothly: true), .init(factor: 1, smoothly: true),
            ])
            #expect(world.feedbackSpy.haptics == [.tick, .tick, .tick])
        }

        @Test func aPinchZoomsFromWhereItStarted() {
            let camera = CameraSpy()
            let vm = returning(camera: camera)
            vm.viewfinderPinched(1.5)
            #expect(camera.zoom.factor == 1.5)
            // Still the same pinch: measured from where the fingers came down, not from the last report.
            vm.viewfinderPinched(1.8)
            #expect(camera.zoom.factor == 1.8)
            #expect(vm.zoomLabel == "Zoom: 1.8×")
            #expect(camera.zooms.allSatisfy { !$0.smoothly })

            vm.viewfinderPinchEnded()
            vm.viewfinderPinched(0.5)
            #expect(camera.zoom.factor == 0.9)
        }

        @Test func aPinchStopsAtTheEndsOfTheRange() {
            let vm = returning(camera: CameraSpy())
            vm.viewfinderPinched(40)
            #expect(vm.zoomTitle == "10×")
            vm.viewfinderPinchEnded()
            vm.viewfinderPinched(0.001)
            #expect(vm.zoomTitle == "0.5×")
        }

        @Test func aPinchLandsOnALensItIsAllButOnWithATick() {
            let camera = CameraSpy()
            let vm = returning(camera: camera)
            vm.viewfinderPinched(1.5)
            #expect(world.feedbackSpy.haptics.isEmpty)
            vm.viewfinderPinched(1.97)
            #expect(camera.zoom.factor == 2)
            #expect(world.feedbackSpy.haptics == [.tick])

            // Staying there asks the camera for nothing more.
            vm.viewfinderPinched(1.98)
            #expect(world.feedbackSpy.haptics == [.tick])
            #expect(camera.zooms.count == 2)
        }

        @Test func pinchingThroughALensTicksOnce() {
            let vm = returning(camera: CameraSpy())
            vm.viewfinderPinched(0.8)
            #expect(world.feedbackSpy.haptics.isEmpty)
            vm.viewfinderPinched(1.3)
            #expect(world.feedbackSpy.haptics == [.tick])
            vm.viewfinderPinched(1.4)
            #expect(world.feedbackSpy.haptics == [.tick])
        }

        @Test func theZoomButtonHidesBehindTheStrip() {
            let vm = returning()
            vm.chipTapped()
            #expect(!vm.isZoomVisible)
            vm.chipTapped()
            #expect(vm.isZoomVisible)
        }

        @Test func thereIsNoZoomWithoutACamera() {
            let camera = CameraSpy()
            camera.availability = .busy
            let vm = returning(camera: camera)
            #expect(!vm.isZoomVisible)
            vm.zoomTapped()
            vm.viewfinderPinched(2)
            #expect(camera.zooms.isEmpty)
            #expect(world.feedbackSpy.haptics.isEmpty)
        }

        @Test func zoomStaysWhileRecording() {
            let camera = CameraSpy()
            let vm = returning(camera: camera)
            vm.select(.video)
            vm.shutterTapped()
            #expect(vm.isRecording)
            #expect(vm.isZoomVisible)
            vm.viewfinderPinched(3)
            #expect(camera.zoom.factor == 3)
        }

        @Test func aStillSceneIsEnlargedToShowTheZoomAndALiveOneIsNot() {
            let still = returning()
            still.zoomTapped()
            #expect(still.zoomTitle == "2×")
            #expect(still.sceneMagnification == 2)

            let live = returning(camera: CameraSpy())
            live.zoomTapped()
            #expect(live.sceneMagnification == 1)
        }

        @Test func theOtherLensStartsAtItsOwnOne() {
            let vm = returning()
            vm.zoomTapped()
            vm.flipTapped()
            #expect(vm.zoomTitle == "1×")
            #expect(vm.sceneMagnification == 1)
        }
    }
}
