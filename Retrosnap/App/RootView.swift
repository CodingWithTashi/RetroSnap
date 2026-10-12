import SwiftUI

/// The app's single window: onboarding, then one `NavigationStack` rooted on the camera, with the toast above both.
struct RootView: View {
    let app: AppDependencies

    var body: some View {
        @Bindable var router = app.router
        DesignLayoutReader {
            ZStack {
                RSColor.ink.ignoresSafeArea()
                switch app.router.root {
                case .onboarding(let step):
                    OnboardingView(step: step, viewModel: app.onboarding, stamp: app.dayLabeler.stamp(for: app.clock.now))
                case .camera:
                    NavigationStack(path: $router.path) {
                        CameraView(viewModel: app.cameraViewModel, stamp: app.dayLabeler.stamp(for: app.clock.now))
                            .background(PopGestureDisabler())
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(for: Route.self) { route in
                                destination(route)
                                    .background(PopGestureDisabler())
                                    .toolbar(.hidden, for: .navigationBar)
                            }
                    }
                    .transition(.opacity)
                }
                ToastHost(toasts: app.toasts)
            }
            .animation(.easeInOut(duration: 0.3), value: app.router.root)
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .result(let id):
            ResultView(viewModel: app.makeResultViewModel(photoID: id))
        case .gallery:
            GalleryView(viewModel: app.makeGalleryViewModel())
        case .viewer(let id):
            ViewerView(viewModel: app.makeViewerViewModel(photoID: id))
        case .edit(let id):
            EditView(viewModel: app.makeEditViewModel(photoID: id))
        case .print(let id):
            PrintView(viewModel: app.makePrintViewModel(photoID: id))
        case .collage(let seed):
            CollageView(viewModel: app.makeCollageViewModel(seedID: seed))
        case .settings:
            SettingsView(viewModel: app.makeSettingsViewModel())
        case .cameraCarousel:
            CameraCarouselView(
                viewModel: app.cameraViewModel, stamp: app.dayLabeler.stamp(for: app.clock.now),
                onClose: app.router.returnToCamera
            )
        }
    }
}

/// Draws the current toast under the status bar, above every screen.
struct ToastHost: View {
    let toasts: ToastCenter
    @Environment(\.designLayout) private var layout

    var body: some View {
        VStack {
            if let toast = toasts.current {
                ToastView(text: toast.text, actionTitle: toast.actionTitle, action: toasts.performAction)
                    .id(toast.id)
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .padding(.top, layout.top(110))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(RSMotion.toast, value: toasts.current)
    }
}
