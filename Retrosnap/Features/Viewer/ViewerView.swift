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
                    guard abs(value.translation.width) > 40 else { return }
                    viewModel.swiped(value.translation.width < 0 ? .left : .right)
                }
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var photo: some View {
        if let photo = viewModel.photo, let picture = viewModel.picture {
            PhotoLookView(
                image: picture, camera: photo.camera, adjustments: photo.adjustments, framed: true,
                stamp: viewModel.stamp, videoDuration: viewModel.badgeText, photoAspect: photo.aspectRatio
            )
                .environment(\.liveFrames, viewModel.movieFrames)
                .aspectRatio(viewModel.displayAspect, contentMode: .fit)
                .frame(maxWidth: viewModel.isInstant ? InstantPrint.viewerWidth : .infinity)
                .id(photo.id)
                .onTapGesture(perform: viewModel.photoTapped)
                .accessibilityElement()
                .accessibilityLabel("\(viewModel.subtitle), \(viewModel.title)")
                .accessibilityAdjustableAction { direction in
                    viewModel.swiped(direction == .increment ? .left : .right)
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
            Color.clear.frame(width: 44, height: 44)
        }
        .frame(height: 44)
    }
}
