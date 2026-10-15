import SwiftUI

struct ViewerView: View {
    @State private var viewModel: ViewerViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: ViewerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.black
            photo
                .padding(.top, layout.top(104))
                .padding(.bottom, layout.bottom(148))

            header
                .padding(.horizontal, 16)
                .padding(.top, layout.top(54))
                .frame(maxHeight: .infinity, alignment: .top)

            PhotoActionRow(style: .plain, onAction: viewModel.perform)
                .padding(.horizontal, 8)
                .padding(.bottom, layout.bottom(36))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard let direction = SwipeDirection(translation: value.translation.width) else { return }
                    viewModel.swiped(direction)
                }
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var photo: some View {
        if let photo = viewModel.photo, let picture = viewModel.picture {
            PhotoLookView(
                image: picture, camera: photo.camera, adjustments: photo.adjustments, framed: !photo.isVideo,
                stamp: viewModel.stamp, videoDuration: viewModel.badgeText, photoAspect: photo.aspectRatio,
                frameDesign: FrameDesign.forPhoto(id: photo.id)
            )
                .environment(\.liveFrames, viewModel.movieFrames)
                .aspectRatio(viewModel.displayAspect, contentMode: .fit)
                .id(photo.id)
                .onTapGesture(perform: viewModel.photoTapped)
                .accessibilityElement()
                .accessibilityLabel(viewModel.photoLabel)
                .accessibilityAdjustableAction { direction in
                    viewModel.swiped(SwipeDirection(direction))
                }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(icon: .chevronLeft, label: "Back to photos", action: viewModel.backTapped)
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text(viewModel.title)
                    .rsText(.text(15, .semibold))
                    .foregroundStyle(RSColor.paper)
                Text(viewModel.subtitle)
                    .rsText(.caption)
                    .foregroundStyle(RSColor.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HeaderSpacer()
        }
        .frame(height: 44)
    }
}
