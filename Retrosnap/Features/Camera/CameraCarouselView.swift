import SwiftUI

/// Design option 1b: every camera as a large card with a bigger sample and room for its description.
struct CameraCarouselView: View {
    let viewModel: CameraViewModel
    let stamp: PhotoStampText
    let onClose: () -> Void
    @Environment(\.designLayout) private var layout
    /// The card at the carousel's leading edge. Set to the selected camera's as the carousel appears, so that
    /// card is in view; set then rather than at first, because the position is only taken once there is a size.
    @State private var leadingCard: CameraStyle.ID?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Cameras") {
                CircleIconButton(icon: .close, label: "Close", action: onClose)
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(CameraStyle.allCases) { camera in
                        card(camera)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, 28)
                .padding(.bottom, 8)
            }
            .contentMargins(.horizontal, 38, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $leadingCard)
            .scrollIndicators(.hidden)
            .onAppear { leadingCard = viewModel.style.id }
            .frame(maxHeight: .infinity, alignment: .top)

            Text("Tap a camera to use it · Swipe for more")
                .rsText(.caption)
                .foregroundStyle(RSColor.secondaryText)
                .padding(.horizontal, 24)
                .padding(.bottom, layout.bottom(44))
        }
        .padding(.top, layout.top(54))
        .background(RSColor.ink)
        .ignoresSafeArea()
    }

    private func card(_ camera: CameraStyle) -> some View {
        let isSelected = camera == viewModel.style
        return Button {
            viewModel.pickFromCarousel(camera)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                PhotoLookView(image: .sample(camera.sample), camera: camera, stamp: stamp)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 10) {
                    Text(camera.name)
                        .rsText(.title.lineHeight(1).tracking(-0.01))
                        .foregroundStyle(RSColor.paper)
                    Spacer(minLength: 0)
                    Text(camera.badge)
                        .rsText(.chip)
                        .foregroundStyle(RSColor.onAccent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color(hex: camera.accentHex), in: Capsule())
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                Text(camera.summary)
                    .rsText(.bodySmall.lineHeight(1.4).multiline())
                    .foregroundStyle(RSColor.tertiaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: BalancedWrap.width(for: camera.summary, fontSize: 15, maxWidth: 274), alignment: .leading)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(width: 314, alignment: .leading)
            .background(Color(hex: camera.cardTintHex), in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 30.5)
                    .strokeBorder(RSColor.amber, lineWidth: 2.5)
                    .padding(-2.5)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .accessibilityLabel("\(camera.name). \(camera.summary)\(isSelected ? " Selected." : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
