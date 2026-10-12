import SwiftUI

struct EditView: View {
    @State private var viewModel: EditViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: EditViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            RSColor.ink

            VStack(spacing: 0) {
                ScreenHeader(title: "Edit") {
                    QuietButton(title: "Cancel", style: .body, horizontalPadding: 12, action: viewModel.cancelTapped)
                } trailing: {
                    Button(action: viewModel.doneTapped) {
                        Text("Done")
                            .rsText(.labelSmall)
                            .foregroundStyle(RSColor.onAmber)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(RSColor.amber, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.horizontal, 12)

                preview
                    .padding(.top, 18)
                Spacer(minLength: 0)
            }
            .padding(.top, layout.top(54))

            Text("Hold the photo to compare")
                .rsText(.caption)
                .foregroundStyle(RSColor.secondaryText)
                .padding(.top, layout.top(540))
                .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 6) {
                ForEach(EditTool.allCases) { tool in
                    ChoiceChip(title: tool.label, isSelected: tool == viewModel.tool) {
                        viewModel.select(tool)
                    }
                }
            }
            .padding(.bottom, layout.bottom(178))
            .frame(maxHeight: .infinity, alignment: .bottom)

            HStack {
                Text(viewModel.tool.label)
                    .rsText(.text(15, .semibold))
                    .foregroundStyle(RSColor.paper)
                Spacer(minLength: 0)
                Text(viewModel.valueText)
                    .rsText(.bodySmall.tabularDigits())
                    .foregroundStyle(RSColor.secondaryText)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, layout.bottom(118))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .accessibilityHidden(true)

            RSSlider(
                value: $viewModel.sliderValue,
                range: Double(viewModel.tool.range.lowerBound)...Double(viewModel.tool.range.upperBound),
                label: viewModel.tool.label,
                valueText: viewModel.valueText
            )
            .padding(.horizontal, 24)
            .padding(.bottom, layout.bottom(76))
            .frame(maxHeight: .infinity, alignment: .bottom)

            QuietButton(title: "Reset", action: viewModel.resetTapped)
                .padding(.bottom, layout.bottom(28))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }

    private var preview: some View {
        let width: CGFloat = viewModel.isInstant ? 300 : 312
        return ZStack(alignment: .topLeading) {
            if let photo = viewModel.photo {
                PhotoLookView(
                    image: photo.image, camera: photo.camera, adjustments: viewModel.displayed,
                    framed: true, stamp: viewModel.stamp
                )
            }
            if viewModel.isComparing {
                Text("Original")
                    .rsText(.caption)
                    .foregroundStyle(RSColor.paper)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RSColor.ink(0.7), in: RoundedRectangle(cornerRadius: 12))
                    .padding(10)
            }
        }
        .frame(width: width, height: width * (viewModel.isInstant ? InstantPrint.size.height / InstantPrint.size.width : 4.0 / 3.0))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !viewModel.isComparing { viewModel.compareBegan() }
                }
                .onEnded { _ in viewModel.compareEnded() }
        )
        .accessibilityElement()
        .accessibilityLabel("Photo preview")
        .accessibilityHint("Hold to compare with the original")
    }
}
