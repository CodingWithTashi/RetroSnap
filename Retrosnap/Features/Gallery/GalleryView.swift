import SwiftUI

struct GalleryView: View {
    @State private var viewModel: GalleryViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: GalleryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 3)

    var body: some View {
        ZStack {
            RSColor.ink
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sections) { section in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(section.title)
                                .rsText(.label)
                                .foregroundStyle(RSColor.paper)
                            Text(section.countText)
                                .rsText(.caption)
                                .foregroundStyle(RSColor.secondaryText)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(section.photos) { photo in
                                Button {
                                    viewModel.open(photo)
                                } label: {
                                    RSColor.surface
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                        .overlay { PhotoLookView(photo: photo, usesThumbnail: true) }
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(viewModel.accessibilityLabel(for: photo))
                            }
                        }
                        .padding(.horizontal, 3)
                    }
                    if viewModel.isEmpty {
                        emptyState
                    }
                }
                .padding(.top, layout.top(104))
                .padding(.bottom, layout.bottom(130))
            }
            .scrollIndicators(.hidden)

            topBar
                .frame(maxHeight: .infinity, alignment: .top)

            cameraButton
                .padding(.bottom, layout.bottom(40))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(icon: .chevronDown, label: "Close photos", action: viewModel.closeTapped)
            Spacer(minLength: 0)
            Text("Photos")
                .rsText(.label)
                .foregroundStyle(RSColor.paper)
                .frame(height: 44)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            CircleIconButton(icon: .gear, label: "Settings", iconSize: 20, lineWidth: 1.8, action: viewModel.settingsTapped)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .frame(height: layout.top(100), alignment: .bottom)
        .background {
            Rectangle().fill(.ultraThinMaterial)
            RSColor.ink(0.86)
        }
    }

    private var cameraButton: some View {
        let primary = viewModel.isActionPrimary
        return Button(action: viewModel.cameraTapped) {
            HStack(spacing: 10) {
                RSIconView(.camera, size: 20, lineWidth: 2)
                Text(viewModel.actionTitle).rsText(.labelSmall)
            }
            .foregroundStyle(primary ? RSColor.onAmber : RSColor.paper)
            .padding(.leading, 18)
            .padding(.trailing, 22)
            .frame(height: 52)
            .background(primary ? RSColor.amber : Color(hex: 0x26231F, opacity: 0.92), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            CSSLinearGradient(degrees: 160, colors: [Color(hex: 0x3A322A), Color(hex: 0x1F1B17)])
                .padding(EdgeInsets(top: 9, leading: 9, bottom: 32, trailing: 9))
                .frame(width: 120, height: 146)
                .background(RSColor.printFrame, in: RoundedRectangle(cornerRadius: 8))
                .compositingGroup()
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 20)
                .accessibilityHidden(true)
            Text("No photos yet")
                .rsText(.heading)
                .foregroundStyle(RSColor.paper)
                .padding(.top, 14)
            Text("Your shots land here the moment you take\nthem.")
                .rsText(.bodySmall.lineHeight(1.4).multiline())
                .foregroundStyle(RSColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity)
        .frame(height: 560)
        .accessibilityElement(children: .combine)
    }
}
