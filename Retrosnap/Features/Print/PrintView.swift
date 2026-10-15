import SwiftUI

struct PrintView: View {
    @State private var viewModel: PrintViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: PrintViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            RSColor.ink

            ScrollView {
                VStack(spacing: 0) {
                    paper
                        .frame(height: 330)
                    options
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            }
            .scrollIndicators(.hidden)
            .padding(.top, layout.top(100))
            .padding(.bottom, layout.bottom(116))

            ScreenHeader(title: "Print") {
                QuietButton(title: "Cancel", style: .body, horizontalPadding: 12, action: viewModel.cancelTapped)
            } trailing: {
                HeaderSpacer(width: 72)
            }
            .padding(.horizontal, 12)
            .padding(.top, layout.top(54))
            .frame(maxHeight: .infinity, alignment: .top)

            PrimaryButton(title: viewModel.actionTitle, action: viewModel.printTapped)
                .padding(.horizontal, 24)
                .padding(.bottom, layout.bottom(44))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }

    /// The photo on its paper, resizing with the chosen size and border.
    private var paper: some View {
        ZStack {
            if let photo = viewModel.photo {
                PhotoLookView(
                    image: photo.image, camera: photo.camera, adjustments: photo.adjustments, stamp: viewModel.stamp,
                    photoAspect: photo.aspectRatio
                )
                .padding(viewModel.paperPadding)
            }
        }
        .frame(width: viewModel.paperSize.width, height: viewModel.paperSize.height)
        .background(RSColor.printPaper, in: RoundedRectangle(cornerRadius: 2))
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: 20, y: 18)
        .animation(RSMotion.paper, value: viewModel.size)
        .animation(RSMotion.paper, value: viewModel.hasBorder)
        .accessibilityElement()
        .accessibilityLabel(viewModel.previewLabel)
    }

    private var options: some View {
        VStack(spacing: 0) {
            row(height: 60, trailingPadding: 12) {
                Text("Size").rsText(.body)
                Spacer(minLength: 0)
                SegmentedPill(
                    options: PrintSize.allCases.map { ($0, $0.label) },
                    selection: viewModel.size,
                    style: .inset,
                    onSelect: viewModel.select
                )
            }
            divider
            row(height: 60, trailingPadding: 12) {
                Text("Copies").rsText(.body)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    stepButton("−", label: "Fewer copies", action: viewModel.decreaseCopies)
                    Text("\(viewModel.copies)")
                        .rsText(.body.tabularDigits())
                        .frame(width: 32)
                        .accessibilityLabel(viewModel.copiesLabel)
                    stepButton("+", label: "More copies", action: viewModel.increaseCopies)
                }
            }
            divider
            Button(action: viewModel.toggleBorder) {
                row(height: 60, trailingPadding: 16) {
                    Text("White border").rsText(.body)
                    Spacer(minLength: 0)
                    RSSwitch(isOn: viewModel.hasBorder)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(viewModel.hasBorder ? "On" : "Off")
            divider
            Button(action: viewModel.toggleMore) {
                row(height: 56, trailingPadding: 16) {
                    Text("More options").rsText(.bodySmall)
                    Spacer(minLength: 0)
                    RSIconView(.chevronDown, size: 16, lineWidth: 2.2)
                        .rotationEffect(.degrees(viewModel.isMoreExpanded ? 180 : 0))
                        .animation(RSMotion.selection, value: viewModel.isMoreExpanded)
                }
                .foregroundStyle(RSColor.secondaryText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if viewModel.isMoreExpanded {
                Button(action: viewModel.printerTapped) {
                    detail("Printer", viewModel.printerName)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                detail("Paper", viewModel.paperName)
            }
        }
        .foregroundStyle(RSColor.paper)
        .background(RSColor.surface, in: RoundedRectangle(cornerRadius: RSRadius.group))
    }

    private var divider: some View {
        RSColor.hairline.frame(height: 1)
    }

    private func row(height: CGFloat, trailingPadding: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 0, content: content)
            .padding(.leading, 16)
            .padding(.trailing, trailingPadding)
            .frame(height: height)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20))
                .foregroundStyle(RSColor.paper)
                .frame(width: 44, height: 36)
                .background(RSColor.raised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            divider
            HStack {
                Text(label).rsText(.bodySmall)
                Spacer(minLength: 0)
                Text(value).rsText(.bodySmall).foregroundStyle(RSColor.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
        }
        .accessibilityElement(children: .combine)
    }
}
