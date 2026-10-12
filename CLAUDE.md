# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

RetroSnap is a vintage-camera app for iPhone, written in SwiftUI with no third-party dependencies (bundle id `com.retrosnap.vintagecamera`, portrait only, app target iOS 17.0).

It is a port of the HTML/CSS prototype in `docs/retrosnap-mobile-app-design/project/`, and the code refers to that prototype constantly: a "board" is one of its static screens, and many raw values and constants are its ids and CSS numbers.

- `RetroSnap.dc.html`: the primary design, with every board and the design system.
- `RetroSnapApp.dc.html`: the interactive prototype and its app logic.
- `Photo.dc.html`: the Photo component, with the `LOOKS` table and `renderVals()`.

The goal is to match the prototype pixel for pixel. Read the HTML and CSS source for dimensions, colours and layout rules; do not render the design files in a browser or screenshot them unless asked.

Current state: on a device everything is real: the camera (photo and video, zoom, flash), permissions, location, the photo library on disk, saving to Photos, the share sheet and AirPrint. The simulator has no camera, so `MockCameraService` stands in for it there and serves one still scene per lens. The Privacy and Help rows of Settings open the addresses in `AppLinks.released` (`App/AppConfig.swift`) and are hidden while those are nil.

## Commands

There is one scheme, `Retrosnap`. Every command takes the same project, scheme and destination:

```bash
# Build
xcodebuild build -project Retrosnap.xcodeproj -scheme Retrosnap \
  -destination 'platform=iOS Simulator,name=Retrosnap 16e'

# All unit tests
xcodebuild test -project Retrosnap.xcodeproj -scheme Retrosnap \
  -destination 'platform=iOS Simulator,name=Retrosnap 16e' \
  -only-testing:RetrosnapTests

# One suite, or one test (Swift Testing: the test name keeps its parentheses)
  -only-testing:RetrosnapTests/GalleryViewModelTests
  -only-testing:'RetrosnapTests/GalleryViewModelTests/aNewShotLeadsToday()'

# One UI test (XCTest: no parentheses)
  -only-testing:RetrosnapUITests/RetrosnapUITests/testVideoRecordsThenShowsTheClip
```

- `xcodebuild test` without `-only-testing` also runs the UI tests, which take about 20 seconds each.
- If a run fails with "Failed to clone device", add `-parallel-testing-enabled NO`. The tests then run on the simulator itself instead of a clone.
- Tests need an iOS 26.2+ simulator, because the test targets' deployment target is 26.2 while the app's is 17.0. The simulators on this machine are `Retrosnap 16e` (iOS 26.3) and `Retrosnap 16 iOS18` (build and run only; its destination needs `,OS=18.0`). List them with `xcrun simctl list devices available`.
- The UI test `testOnboardingShowsOnceAndTheCameraLibraryAndSettingsAreRemembered` launches with `-rsLive fresh`, which wipes the app's saved settings and photos on the simulator it runs on.
- No linter or formatter is configured.
- The project uses file-system-synchronized groups: a file created under `Retrosnap/`, `RetrosnapTests/` or `RetrosnapUITests/` is in its target already. Do not edit `project.pbxproj` to add files.
- `Retrosnap/Info.plist` holds only `UIAppFonts`. Everything else in the Info.plist (usage descriptions, orientations, display name) comes from the `INFOPLIST_KEY_*` build settings in `project.pbxproj`.

### Opening the app in a designed state

Debug builds read `-rs…` launch arguments (`App/LaunchScenario.swift`) that open any screen in any state the design shows, including ones mock data never reaches by itself. Use them to check a screen against its board:

```bash
xcrun simctl install booted "<BUILT_PRODUCTS_DIR>/Retrosnap.app"
xcrun simctl launch --terminate-running-process booted com.retrosnap.vintagecamera \
  -rsScreen gallery -rsVariant empty
xcrun simctl io booted screenshot out.png
```

| Argument | Values |
| --- | --- |
| `-rsScreen` | `welcome` `how` `permCam` `permLib` `camera` `carousel` `result` `gallery` `viewer` `edit` `collage` `print` `settings`, plus `catalog` (the design system on one page) and `look` (one camera look full screen) |
| `-rsVariant` | `capture` `saved` `processing` `recording` `videoMode` `video` `denied` `unavailable` `libDenied` `lowStorage` `empty` |
| `-rsCamera` | `film` `disp` `inst` `digi` `vhs` |
| `-rsScenario returning` | skips onboarding and opens on the camera |
| `-rsLive` | `1` runs the live services on what earlier launches saved; `fresh` wipes that first |

`LaunchScenario.swift` has the rest (`-rsSheet`, `-rsFirstRun`, `-rsTool`, `-rsEdit`, `-rsCollageStep`, `-rsPhoto`, `-rsSelector`, `-rsAfterCapture`). UI tests pass the same arguments through `app.launchArguments`.

## Architecture

### Composition root, and live versus mock

`RetrosnapApp` picks one of three launches: the unit-test host (an empty window and no services, when `XCTestConfigurationFilePath` is set), the debug design catalog, or the app with an `AppDependencies`.

`AppDependencies` is the only place services are constructed. It owns every service, the `AppRouter`, the `ToastCenter` and the two long-lived view models (onboarding and camera), and has a `make…ViewModel` factory for each pushed screen.

`LaunchScenario.runsLive(onSimulator:)` decides which services run:

- A device launched with no `-rs` arguments runs the live ones (`Services/Live`): `LiveCameraService`, `DiskPhotoStore`, `UserDefaultsSettingsStore`, `LivePermissionService`, `LiveLocationService`, `LiveStorageMonitor`, `PhotoExporter`, `PhotoShareSheet`, `AirPrinter`, `ClipPlayer` and `PhotoImageLoader`.
- The simulator, and any launch with a `-rs` argument, runs in-memory mocks on `FixedClock.design` (11 October 2026, 4:12 PM) with the 13 `SeedData` photos, unless `-rsLive` is passed.

So running in the simulator from Xcode shows seeded mock data and saves nothing.

The mocks, `SeedData`, `LaunchScenario`, the design catalog and `MockSamples.xcassets` are debug-only: a Release build compiles them out and always runs live.

### Navigation

`AppRouter` is the single source of navigation state: `root` (an onboarding step, or the camera) and `path: [Route]`, bound to the one `NavigationStack` in `RootView`. The camera is the permanent root and every other screen is a `Route` stacked on it.

- View models call router methods (`push`, `back`, `returnToCamera`, `returnToGallery`, `showResult`); views never navigate themselves.
- Steps inside a screen (the three collage steps, viewer paging) are view-model state, not routes.
- The navigation bar is hidden and swipe-back is disabled (`PopGestureDisabler`); each screen draws its own header.
- `ToastCenter` is drawn above the stack, so a toast such as "Photo deleted · Undo" survives the screen change that caused it.

### View models and services

- Each screen in `Features/` is a `View` plus an `@Observable final class` view model. The view takes its view model in `init` and keeps it in `@State`.
- View models hold the logic and the copy, including VoiceOver labels; views are layout.
- Dependencies are protocol existentials (`any PhotoStoring`) passed explicitly through `init` and stored as `@ObservationIgnored private let`. There are no singletons, default arguments or environment objects for services.
- Delayed and repeating work goes through `Scheduling` (`after`, `every`), and "now" comes from `DateProviding`, so tests can run on virtual time. Do not use `Task.sleep`, `Timer` or `Date()` in a view model.

### The camera

- `CameraServicing` is what the camera screen talks to. `LiveCameraService` is its face on the main actor; the `AVCaptureSession` itself lives in the `CaptureSession` actor, on its own queue.
- The viewfinder is not a preview layer. Each camera frame becomes a `CGImage` in a `FrameFeed`, and `PhotoPicture` draws a `.live` image from the feed in the `liveFrames` environment value, so the look's shaders apply to it like to any photo.
- Zoom is in the numbers a camera shows (`CameraZoom`: 1 is the main lens, 0.5 the ultra-wide). The back camera is the phone's multi-lens device, and `LensZoom` maps its own zoom numbers onto those.
- The shutter's flash and fly-to-gallery start at the tap, from the viewfinder frame frozen in `LiveCameraService.shotFeed`. The photo lands later (over a second with flash), and until then `CameraViewModel.pendingShot` makes the gallery button show that frozen frame.
- Nothing audio or file related may run on the main actor at the shutter: on a phone the click's `AVAudioPlayer` cost 70 ms to build and 90 ms to start, and opening a HEIC cost 30 ms. `ClickSound` has its own queue, and files are opened in `@concurrent` functions.

### Photos and persistence

- `Photo.image` is a `PhotoImage`: `.sample` (an asset-catalog picture) or `.file(full:thumbnail:)` (file names inside the library folder).
- `PhotoPicture` is the only view that turns a `PhotoImage` into pixels. File images load through the `photoImageLoader` environment value, which is nil while the app runs on mocks.
- `MockPhotoStore` and `DiskPhotoStore` both delegate ordering to the `PhotoList` value type: newest first, and Undo puts a photo back next to its older neighbour.
- `DiskPhotoStore` keeps a versioned `library.json` index beside the photo files in `Application Support/Library`. A deleted photo's files stay on disk for the undo window (the toast duration plus one second), and files no photo owns are removed at the next launch.
- `Photo` is `Codable` and written to that index, and `CameraStyle` and `FlashMode` raw values are written to the user defaults. Those raw values are the prototype's ids and are on disk, so do not rename them.

### The look pipeline

A camera's look is drawn in four stages, each mirroring a part of the prototype's Photo component:

1. `CameraStyle.look` returns a `CameraLook` recipe, transcribed from the `LOOKS` table.
2. `LookRenderModel` combines the recipe with the `PhotoAdjustments` sliders. It is pure and unit-tested, and mirrors `renderVals()`.
3. `PhotoLookView` draws the layers in the prototype's order: image, filtered image, overlays, stamps, then Light and Contrast over everything.
4. `LookShaders` is the only caller of `ShaderLibrary`; `RetroLook.metal` implements the CSS filter and blend maths on gamma-encoded sRGB.

A change to a shader's signature in `RetroLook.metal` needs the matching change in `LookShaders`.

### Design system

`DesignSystem/` ports the prototype's CSS rather than using system styling:

- `DesignLayout` (the `designLayout` environment value) maps offsets measured on the design's 390×844 frame onto the real screen. Screens draw edge to edge with `.ignoresSafeArea()` and position content with `layout.top(y)` and `layout.bottom(y)`.
- Tokens: `RSColor`, `RSTextStyle` applied with `.rsText(…)`, `RSSpacing`, `RSRadius`, `RSMotion`.
- Icons are `RSIcon`, the design's own SVG paths, not SF Symbols. The VT323 font is only for photo stamps.
- `CSSLinearGradient`, `BalancedWrap` and `GlassContainer` / `.glass()` reproduce CSS `linear-gradient`, `text-wrap: pretty` and `backdrop-filter`.

### Concurrency

The app target builds in Swift 5 mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency, so every declaration is main-actor isolated unless it says otherwise:

- Models and other value types are declared `nonisolated`.
- Work that must leave the main actor is a `@concurrent nonisolated` function (see `PhotoImageLoader.decode`).
- The test targets do not have the default isolation, so test suites are annotated `@MainActor`.

### Tests

- Unit tests use Swift Testing: `@MainActor struct …Tests`, `@Test`, `#expect`.
- `RetrosnapTests/Support` has `TestWorld` (a fully mocked app for view-model tests), `ManualScheduler` (virtual time, moved with `advance(by:)`) and `FeedbackSpy`.
- UI tests are XCTest and find elements by accessibility label and visible text. Changing copy or a VoiceOver label can break them, and the same strings are asserted in the view-model unit tests.

## The rules in `.claude/rules/ecc/swift/`

These are generic Swift rules that load for every `.swift` file. Several parts do not describe this project:

- `swift build` and `swift test`: this is an Xcode project, not a Swift package. Use the `xcodebuild` commands above.
- SwiftFormat and SwiftLint: neither is installed or configured.
- Swift 6 strict concurrency and actors for shared state: the app uses the MainActor-by-default setup described above.
- Dependency injection through default parameters: dependencies here are always passed explicitly from `AppDependencies`.
