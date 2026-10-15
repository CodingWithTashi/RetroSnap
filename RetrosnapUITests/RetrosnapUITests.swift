import XCTest

/// Taps through the whole app the way a person would: onboarding, shooting, and every screen behind a photo.
final class RetrosnapUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: Helpers

    private func button(_ label: String) -> XCUIElement {
        app.buttons[label].firstMatch
    }

    private func buttonStarting(with prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func launch(_ arguments: String...) {
        app.launchArguments = arguments
        app.launch()
    }

    private func tapButton(startingWith prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = buttonStarting(with: prefix)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "No button starting “\(prefix)”", file: file, line: line)
        element.tap()
    }

    private func toggle(_ label: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.switches[label].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "No switch “\(label)”", file: file, line: line)
        return element
    }

    private func tap(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = button(label)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "No button “\(label)”", file: file, line: line)
        element.tap()
    }

    private func expectText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Expected “\(text)” on screen", file: file, line: line)
    }

    private func expectButton(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button(label).waitForExistence(timeout: 5), "Expected button “\(label)”", file: file, line: line)
    }

    /// Answers a system permission prompt if one is up. It belongs to SpringBoard, not to the app.
    private func answerSystemPrompt(_ button: String) {
        let prompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons[button]
        if prompt.waitForExistence(timeout: 3) {
            prompt.tap()
        }
    }

    private func finishOnboarding() {
        tap("Continue")
        expectText("Step 1")
        tap("Continue")
        expectText("Allow camera access")
        tap("Allow Camera")
        expectText("Save to your photos")
    }

    // MARK: Golden path

    @MainActor
    func testFirstPhotoThenSecondPhotoStaysInTheCamera() throws {
        app.launch()
        finishOnboarding()
        tap("Allow Photos")

        // First launch: the strip is open and D Classic is already on.
        expectText("Choose a camera")
        expectButton("Take photo")

        // One tap on a card switches the look and folds the strip into the chip.
        tapButton(startingWith: "Inst C.")
        expectButton("Camera: Inst C. Change camera")

        // The first photo opens the result.
        tap("Take photo")
        expectButton("Take another")
        expectText("Inst C · Just now")
        expectText("Saved to Photos")
        tap("Take another")

        // Back in the camera on the same look; the second photo stays here.
        expectButton("Camera: Inst C. Change camera")
        tap("Take photo")
        expectText("Saved · Inst C")
        expectButton("Take photo")
        XCTAssertFalse(button("Take another").exists)
    }

    @MainActor
    func testNotNowStillReachesTheCameraWithABanner() throws {
        app.launch()
        finishOnboarding()
        tap("Not now")

        expectText("Saving inside RetroSnap only")
        tap("Allow")
        expectText("Saving to Photos")
        expectButton("Take photo")
    }

    // MARK: Across launches

    @MainActor
    func testOnboardingShowsOnceAndTheCameraLibraryAndSettingsAreRemembered() throws {
        launch("-rsLive", "fresh")
        tap("Continue")
        tap("Continue")
        // The live services ask iOS itself, so the camera prompt may come up here.
        tap("Allow Camera")
        answerSystemPrompt("Allow")
        expectText("Save to your photos")
        tap("Not now")
        expectText("Saving inside RetroSnap only")

        // Leave the camera on Inst C with the flash on, take one photo, then turn the timer on.
        tapButton(startingWith: "Inst C.")
        tap("Flash: auto")
        tap("Take photo")
        tap("Take another")
        tap("Self-timer off")

        tap("Open photos")
        tap("Settings")
        let haptics = toggle("Haptics")
        haptics.tap()
        XCTAssertEqual(haptics.value as? String, "Off")

        app.terminate()
        launch("-rsLive", "1")

        // Straight to the camera, as it was left: no onboarding and no first-launch strip.
        expectButton("Camera: Inst C. Change camera")
        expectButton("Flash: on")
        expectButton("Self-timer on, 3 seconds")
        XCTAssertFalse(button("Continue").exists)

        // The photo and the setting are still there.
        tap("Open photos")
        expectButton("Inst C photo, Today")
        tap("Settings")
        XCTAssertTrue(haptics.waitForExistence(timeout: 5))
        XCTAssertEqual(haptics.value as? String, "Off")
    }

    // MARK: Behind a photo

    @MainActor
    func testGalleryViewerEditPrintCollageDeleteAndSettings() throws {
        launch("-rsScenario", "returning")

        // Returning user: straight to the camera, no prompts.
        expectButton("Take photo")
        tap("Open photos")
        expectText("Photos")

        // Viewer, with paging that must not pop the screen.
        let firstTile = app.buttons["D Classic photo, Today"].firstMatch
        XCTAssertTrue(firstTile.waitForExistence(timeout: 5))
        firstTile.tap()
        expectButton("Back to photos")
        expectText("D Classic")
        app.swipeLeft()
        expectText("Disposable")
        expectButton("Back to photos")
        app.swipeRight()
        expectText("D Classic")

        // Edit, then back to the viewer.
        tap("Edit")
        expectText("Hold the photo to compare")
        tap("Warmth")
        tap("Done")
        expectText("Edits saved")
        expectButton("Back to photos")

        // Print two copies, then back to the viewer.
        tap("Print")
        tap("More copies")
        tap("Print 2 copies")
        expectText("Sent to Living Room Printer")
        expectButton("Back to photos")

        // Collage: layout, pick, arrange, save. Saving lands on the gallery.
        tap("Collage")
        expectText("Choose a layout")
        tap("Choose 3 photos")
        expectText("1 of 3 selected")
        let unpicked = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' photo'"))
        unpicked.element(boundBy: 0).tap()
        unpicked.element(boundBy: 0).tap()
        tap("Next")
        expectText("Tap two photos to swap them")
        tap("Photo 1")
        expectText("Now tap where it should go")
        tap("Photo 3")
        tap("Save collage")
        expectText("Collage saved to Photos")
        expectText("Photos")

        // Delete with Undo.
        let tile = app.buttons["Disposable photo, Today"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        tap("Delete")
        expectText("Photo deleted")
        XCTAssertFalse(app.buttons["Disposable photo, Today"].exists)
        tap("Undo")
        expectButton("Disposable photo, Today")

        // Settings and back, then back to the camera.
        tap("Settings")
        let haptics = toggle("Haptics")
        XCTAssertEqual(haptics.value as? String, "On")
        haptics.tap()
        XCTAssertEqual(haptics.value as? String, "Off")
        // About is a fact to read, not a button; Privacy and Help are the rows that lead somewhere.
        expectText("About, Version 1.0")
        XCTAssertFalse(buttonStarting(with: "About").exists)
        expectButton("Privacy")
        expectButton("Help")
        tap("Back")
        tap("Close photos")
        expectButton("Take photo")
    }

    // MARK: From the library

    @MainActor
    func testAPictureFromTheLibraryGetsItsLookAndIsDeveloped() throws {
        launch("-rsScenario", "returning")

        // The gallery's add button opens the picker; the mock hands a pick over at once.
        tap("Open photos")
        tap("Add from your library")
        expectButton("Develop photo")
        expectButton("Camera: D Classic. Change camera")

        // The same strip as the camera's; a card changes the look.
        tap("Camera: D Classic. Change camera")
        tapButton(startingWith: "Digicam.")
        expectButton("Camera: Digicam. Change camera")

        // The shutter develops it: the result shows it as just taken, and offers another pick.
        tap("Develop photo")
        expectButton("Develop another")
        expectText("Digicam · Just now")
        expectText("Saved to Photos")
        tap("Back to photos")
        expectText("Photos")
        expectButton("Digicam photo, Today")

        // Cancelling a pick throws it away.
        tap("Add from your library")
        tap("Cancel")
        expectText("Photos")
        XCTAssertFalse(button("Develop photo").exists)
    }

    @MainActor
    func testZoomButtonAndPinchZoomTheViewfinder() throws {
        launch("-rsScenario", "returning")

        // The button steps through the lenses and comes round again.
        tap("Zoom: 1×")
        expectButton("Zoom: 2×")
        tap("Zoom: 2×")
        expectButton("Zoom: 1×")

        // Two fingers spreading zoom in, and are not taken for a swipe to the next camera.
        let viewfinder = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Viewfinder")).firstMatch
        XCTAssertTrue(viewfinder.waitForExistence(timeout: 5))
        viewfinder.pinch(withScale: 2, velocity: 2)
        let zoom = buttonStarting(with: "Zoom: ")
        XCTAssertTrue(zoom.waitForExistence(timeout: 5))
        XCTAssertNotEqual(zoom.label, "Zoom: 1×")
        expectButton("Camera: D Classic. Change camera")

        // One finger still swipes to the next camera.
        viewfinder.swipeLeft()
        expectButton("Camera: Disposable. Change camera")
    }

    @MainActor
    func testVideoRecordsThenShowsTheClip() throws {
        launch("-rsScenario", "returning", "-rsCamera", "vhs")

        tap("Video")
        tap("Start recording")
        expectButton("Stop recording")
        tap("Stop recording")
        expectButton("Take another")
        expectText("Camcorder · Just now")
        tap("Delete")
        expectText("Photo deleted")
        expectButton("Start recording")
    }

    /// A probe for a phone: the look screen of every fitted camera, screenshotted and kept in the result bundle,
    /// so the phone's own rendering can be measured against the simulator's and the bake (the calibration notes in
    /// `docs/camera-lineup.md`). On the simulator it only checks that the screens come up.
    @MainActor
    func testLookScreensAreKeptAsScreenshotsForTheDeviceProbe() throws {
        // The look screen is the phone against the simulator (`tools/device_probe.py`); the viewer is the phone
        // against the bake of the same photo (`tools/screen_vs_bake.py`), the export checked on a device.
        for camera in ["negative", "plastic35", "slide", "mediumFormat", "tlr", "film", "inst", "compactPro", "classicSLR", "instSquare"] {
            for screen in ["look", "viewer"] {
                let probe = XCUIApplication()
                probe.launchArguments = ["-rsScreen", screen, "-rsCamera", camera]
                probe.launch()
                sleep(5)
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "\(screen)-\(camera)"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTAssertTrue(probe.state == .runningForeground)
                probe.terminate()
            }
        }
    }
}
