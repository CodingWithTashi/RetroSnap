import SwiftUI

@main
struct RetrosnapApp: App {
    private let launch = Launch.current

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .unitTests:
                // Hosting the unit tests: nothing to show and no services to start.
                Color.clear
            case .app(let dependencies):
                RootView(app: dependencies)
            #if DEBUG
            case .designCatalog(let scenario):
                DesignCatalogView(scenario: scenario)
                    .preferredColorScheme(.dark)
            #endif
            }
        }
    }
}

private enum Launch {
    case unitTests
    case app(AppDependencies)
    #if DEBUG
    case designCatalog(LaunchScenario)
    #endif

    static var current: Launch {
        let process = ProcessInfo.processInfo
        if process.environment["XCTestConfigurationFilePath"] != nil {
            return .unitTests
        }
        #if DEBUG
        let scenario = LaunchScenario(arguments: process.arguments)
        if scenario.screen == .catalog || scenario.screen == .look {
            return .designCatalog(scenario)
        }
        return .app(AppDependencies(scenario: scenario))
        #else
        return .app(AppDependencies())
        #endif
    }
}
