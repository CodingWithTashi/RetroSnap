import SwiftUI

struct CollageView: View {
    @State private var viewModel: CollageViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: CollageViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            RSColor.ink

            switch viewModel.step {
            case .layout:
                // On a phone the six layouts fit as the design draws them. A wide screen keeps them phone-sized
                // instead of stretching them off the bottom, and a short one scrolls.
                ScrollView {
                    layoutStep
                        .frame(maxWidth: Self.widestLayoutGrid)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, layout.top(124))
                        .padding(.bottom, layout.bottom(120))
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            case .pick:
                pickStep
                    .padding(.top, layout.top(110))
                    .padding(.bottom, layout.bottom(120))
            case .arrange:
                arrangeStep
            }

            ScreenHeader(title: viewModel.title, subtitle: viewModel.subtitle) {
                CircleIconButton(icon: .chevronLeft, label: "Back", action: viewModel.backTapped)
            } trailing: {
                HeaderSpacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, layout.top(54))
            .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 12) {
                if viewModel.step == .arrange {
                    CircleIconButton(
                        icon: .share, label: "Share collage", iconSize: 22, lineWidth: 1.8, diameter: 56,
                        fill: RSColor.raised, action: viewModel.shareTapped
                    )
                }
                PrimaryButton(title: viewModel.actionTitle, isDimmed: !viewModel.isActionEnabled, action: viewModel.actionTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, layout.bottom(44))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }

    // MARK: Step 1

    /// Wider than any phone, so only an iPad is held back by it.
    private static let widestLayoutGrid: CGFloat = 480

    private var layoutStep: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3), spacing: 14) {
            ForEach(CollageTemplate.allCases) { template in
                let isSelected = template == viewModel.template
                Button {
                    viewModel.select(template)
                } label: {
                    VStack(spacing: 8) {
                        RSColor.surface
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .overlay {
                                TemplateCells(template: template, gap: 2) { _ in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(isSelected ? RSColor.paper : RSColor.toggleOff)
                                }
                                .padding(10)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: RSRadius.card))
                            .selectionRing(cornerRadius: RSRadius.card, isSelected: isSelected)
                        Text(template.label)
                            .rsText(.text(13, .semibold))
                            .foregroundStyle(isSelected ? RSColor.paper : RSColor.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(RSMotion.choice, value: isSelected)
                .accessibilityLabel(viewModel.templateLabel(for: template))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: Step 2

    private var pickStep: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 3), spacing: 3) {
                ForEach(viewModel.candidates) { photo in
                    let number = viewModel.pickNumber(for: photo.id)
                    Button {
                        viewModel.togglePick(photo.id)
                    } label: {
                        RSColor.surface
                            .aspectRatio(Photo.cameraAspect, contentMode: .fit)
                            .overlay {
                                PhotoLookView(
                                    image: photo.image, camera: photo.camera, adjustments: photo.adjustments,
                                    usesThumbnail: true
                                )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(RSColor.amber, lineWidth: 3)
                                    .opacity(number == nil ? 0 : 1)
                            }
                            .overlay(alignment: .topTrailing) {
                                Text(number.map(String.init) ?? "")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(RSColor.onAmber)
                                    .frame(width: 24, height: 24)
                                    .background(number == nil ? RSColor.ink(0.3) : RSColor.amber, in: Circle())
                                    .overlay { Circle().strokeBorder(RSColor.paper, lineWidth: 2) }
                                    .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.pickLabel(for: photo))
                    .accessibilityAddTraits(number == nil ? [] : .isSelected)
                }
            }
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Step 3

    private var arrangeStep: some View {
        ZStack {
            let photos = viewModel.arrangedPhotos
            TemplateCells(template: viewModel.template, gap: viewModel.cellGap) { index in
                Button {
                    viewModel.cellTapped(index)
                } label: {
                    ZStack {
                        RSColor.raised
                        if let photo = photos.indices.contains(index) ? photos[index] : photos.first {
                            PhotoLookView(image: photo.image, camera: photo.camera, adjustments: photo.adjustments)
                        }
                    }
                    .overlay {
                        Rectangle()
                            .strokeBorder(RSColor.amber, lineWidth: 3)
                            .opacity(viewModel.swapSelection == index ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.cellLabel(for: index))
                .accessibilityAddTraits(viewModel.swapSelection == index ? .isSelected : [])
            }
            .padding(viewModel.frameInset)
            .frame(width: viewModel.frameSize.width, height: viewModel.frameSize.height)
            .background(Color(hex: viewModel.border.hex), in: RoundedRectangle(cornerRadius: 4))
            .compositingGroup()
            .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
            .padding(.top, layout.top(118))
            .frame(maxHeight: .infinity, alignment: .top)

            Text(viewModel.hint)
                .rsText(.caption)
                .foregroundStyle(RSColor.secondaryText)
                .padding(.bottom, layout.bottom(196))
                .frame(maxHeight: .infinity, alignment: .bottom)

            HStack(spacing: 8) {
                ForEach(CollageBorder.allCases) { border in
                    ChoiceChip(title: border.label, isSelected: border == viewModel.border, swatch: Color(hex: border.hex)) {
                        viewModel.select(border)
                    }
                }
            }
            .padding(.bottom, layout.bottom(136))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Lays a view out in each cell of a template. Cells are percentages of the frame, inset by `gap` on every side.
private struct TemplateCells<Cell: View>: View {
    let template: CollageTemplate
    let gap: CGFloat
    @ViewBuilder var cell: (Int) -> Cell

    var body: some View {
        GeometryReader { proxy in
            let cells = CollageLayout.cells(of: template, in: proxy.size, gap: gap)
            ZStack(alignment: .topLeading) {
                ForEach(cells.indices, id: \.self) { index in
                    let rect = cells[index]
                    cell(index)
                        .frame(width: rect.width, height: rect.height)
                        .clipped()
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}
