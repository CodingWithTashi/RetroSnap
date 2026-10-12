import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.designLayout) private var layout

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CircleIconButton(icon: .chevronLeft, label: "Back", action: viewModel.backTapped)
                    .padding(.horizontal, 16)
                Text("Settings")
                    .rsText(.title)
                    .foregroundStyle(RSColor.paper)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)

                ForEach(viewModel.groups, id: \.self) { rows in
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            rowView(row)
                                .overlay(alignment: .top) {
                                    if row.id != rows.first?.id {
                                        RSColor.hairline.frame(height: 1)
                                    }
                                }
                        }
                    }
                    .background(RSColor.surface, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Text(viewModel.footer)
                    .rsText(.caption.lineHeight(1.5).multiline())
                    .foregroundStyle(RSColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 60)
            }
            .padding(.top, layout.top(54))
        }
        .scrollIndicators(.hidden)
        .background(RSColor.ink)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func rowView(_ row: SettingsRow) -> some View {
        switch row.kind {
        case .toggle(let toggle):
            Button {
                viewModel.toggle(toggle)
            } label: {
                rowLabel(row.label) {
                    RSSwitch(isOn: viewModel.isOn(toggle))
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(viewModel.isOn(toggle) ? "On" : "Off")
        case .link(let value):
            Button {
                viewModel.linkTapped(row.label)
            } label: {
                rowLabel(row.label) {
                    HStack(spacing: 6) {
                        Text(value).rsText(.bodySmall)
                        RSIconView(.chevronRight, size: 14, lineWidth: 2.4)
                    }
                    .foregroundStyle(RSColor.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func rowLabel(_ label: String, @ViewBuilder accessory: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .rsText(.body)
                .foregroundStyle(RSColor.paper)
            Spacer(minLength: 0)
            accessory()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
