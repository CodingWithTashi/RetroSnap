#if DEBUG
import Foundation

/// Launch arguments that open the app in any designed state, mirroring the prototype's props.
/// Used to check each screen against the design and to reach states mock data never produces by itself
/// (camera denied or busy, low storage, returning user). Read only in debug builds.
///
///     -rsScreen gallery -rsVariant empty
///     -rsScreen camera -rsCamera inst -rsSheet 1
///     -rsScreen result -rsCamera slide
///     -rsScenario returning
///     -rsLive fresh
nonisolated struct LaunchScenario: Equatable, Sendable {
    enum Screen: String, Sendable {
        case welcome, how, permCam, permLib
        case camera, carousel, result, gallery, viewer, edit, collage, print, settings
        /// Debug-only design system pages.
        case catalog, look
    }

    /// The screens that open on one photo. With `-rsCamera`, that photo is posed as taken with the camera.
    static let photoScreens: Set<Screen> = [.result, .viewer, .edit, .print, .collage]

    enum Variant: String, Sendable {
        case capture, saved, processing, recording, videoMode, video
        case denied, unavailable, libDenied, lowStorage, empty
    }

    /// What the live services start from when a launch asks for them where mocks would run.
    enum LiveData: String, Sendable {
        /// Whatever earlier launches saved.
        case kept = "1"
        /// Nothing: saved settings and photos are wiped first.
        case fresh
    }

    var screen: Screen?
    var variant: Variant?
    var camera: CameraStyle?
    var firstRun = false
    var sheet = false
    var collageStep = 1
    var tool: EditTool?
    var editPreset: PhotoAdjustments?
    var photoID: Photo.ID?
    var selector = CameraSelectorStyle.strip
    var reviewRule = CaptureReviewRule.first
    /// Skip onboarding and open on the camera with no prompts.
    var isReturningUser = false
    /// Run the live services, for checking in the simulator what otherwise needs a device.
    var liveData: LiveData?
    /// Any scenario argument was passed.
    private var isScripted = false

    init() {}

    init(arguments: [String]) {
        func value(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        func isOn(_ flag: String) -> Bool {
            ["1", "true", "yes"].contains(value(flag)?.lowercased() ?? "")
        }

        screen = value("-rsScreen").flatMap(Screen.init(rawValue:))
        variant = value("-rsVariant").flatMap(Variant.init(rawValue:))
        camera = value("-rsCamera").flatMap(CameraStyle.init(rawValue:))
        firstRun = isOn("-rsFirstRun")
        sheet = isOn("-rsSheet")
        collageStep = min(3, max(1, value("-rsCollageStep").flatMap(Int.init) ?? 1))
        tool = value("-rsTool").flatMap(EditTool.init(rawValue:))
        editPreset = value("-rsEdit").map(Self.adjustments(from:))
        photoID = value("-rsPhoto")
        selector = value("-rsSelector").flatMap(CameraSelectorStyle.init(rawValue:)) ?? .strip
        reviewRule = value("-rsAfterCapture").flatMap(CaptureReviewRule.init(rawValue:)) ?? .first
        isReturningUser = value("-rsScenario") == "returning"
        liveData = value("-rsLive").flatMap(LiveData.init(rawValue:))
        isScripted = arguments.contains { $0.hasPrefix("-rs") }
    }

    /// A device runs the live services. The simulator and every scenario stay on mocks unless `-rsLive` says otherwise.
    func runsLive(onSimulator: Bool) -> Bool {
        liveData != nil || (!onSimulator && !isScripted)
    }

    var config: AppConfig {
        AppConfig(selector: selector, reviewRule: reviewRule)
    }

    /// Where the app opens: the root and what is stacked on the camera.
    func navigation(firstPhotoID: Photo.ID?) -> (root: AppRouter.Root, path: [Route]) {
        let photo = photoID ?? firstPhotoID
        switch screen {
        case nil:
            return (isReturningUser ? .camera : .onboarding(.welcome), [])
        case .welcome:
            return (.onboarding(.welcome), [])
        case .how:
            return (.onboarding(.howItWorks), [])
        case .permCam:
            return (.onboarding(.cameraPermission), [])
        case .permLib:
            return (.onboarding(.photosPermission), [])
        case .camera, .catalog, .look:
            return (.camera, [])
        case .carousel:
            return (.camera, [.cameraCarousel])
        case .gallery:
            return (.camera, [.gallery])
        case .settings:
            return (.camera, [.gallery, .settings])
        case .result:
            return (.camera, photo.map { [.result($0)] } ?? [])
        case .viewer:
            return (.camera, [.gallery] + (photo.map { [.viewer($0)] } ?? []))
        case .edit:
            return (.camera, [.gallery] + (photo.map { [.viewer($0), .edit($0)] } ?? []))
        case .print:
            return (.camera, [.gallery] + (photo.map { [.viewer($0), .print($0)] } ?? []))
        case .collage:
            return (.camera, [.gallery] + (photo.map { [.viewer($0), .collage(seed: $0)] } ?? []))
        }
    }

    /// Parses "warmth=18,grain=64" using the prototype's slider keys.
    private static func adjustments(from text: String) -> PhotoAdjustments {
        var adjustments = PhotoAdjustments.neutral
        for pair in text.split(separator: ",") {
            let parts = pair.split(separator: "=")
            guard parts.count == 2, let tool = EditTool(rawValue: String(parts[0])), let amount = Int(parts[1]) else { continue }
            adjustments[keyPath: tool.keyPath] = min(tool.range.upperBound, max(tool.range.lowerBound, amount))
        }
        return adjustments
    }
}
#endif
