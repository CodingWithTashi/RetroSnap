import SwiftUI

struct ResultView: View {
    @State private var viewModel: ResultViewModel
    @State private var developCover = 1.0
    @Environment(\.designLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: ResultViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            RSColor.ink
            VStack(spacing: 0) {
                header
                print
                    .padding(.top, 24)
                Text(viewModel.metaText)
                    .rsText(.caption)
                    .foregroundStyle(RSColor.secondaryText)
                    .padding(.top, 16)
                Spacer(minLength: 0)
            }
            .padding(.top, layout.top(54))

            PhotoActionRow(style: .chips, onAction: viewModel.perform)
                .padding(.bottom, layout.bottom(122))
                .frame(maxHeight: .infinity, alignment: .bottom)

            PrimaryButton(
                title: viewModel.primaryTitle, icon: viewModel.primaryIcon, isDimmed: viewModel.isPrimaryDimmed,
                action: viewModel.primaryTapped
            )
                .padding(.horizontal, 24)
                .padding(.bottom, layout.bottom(44))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.appeared()
            withAnimation(.easeOut(duration: RSMotion.developDuration)) {
                developCover = 0
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(icon: .close, label: viewModel.closeLabel, action: viewModel.closeTapped)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if !viewModel.isDeveloping {
                    RSIconView(.check, size: 14, lineWidth: 3)
                        .foregroundStyle(RSColor.amber)
                }
                Text(viewModel.statusText)
                    .rsText(.caption)
                    .foregroundStyle(RSColor.secondaryText)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var print: some View {
        let isInstant = viewModel.isInstant
        let width: CGFloat = isInstant ? 296 : 312
        return ZStack {
            if let photo = viewModel.photo {
                PhotoLookView(photo: photo, framed: true, stamp: viewModel.stamp)
            }
            if let progress = viewModel.processingProgress {
                processingCover(progress)
            } else if !reduceMotion {
                // The print develops: a warm dark cover fades away.
                CSSLinearGradient(degrees: 160, colors: [Color(hex: 0x4A3F33), Color(hex: 0x1F1B17)])
                    .opacity(developCover)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: width / viewModel.displayAspect)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .compositingGroup()
        .shadow(color: .black.opacity(0.55), radius: 25, y: 24)
        .rotationEffect(.degrees(isInstant ? -1.5 : 0))
        .accessibilityElement()
        .accessibilityLabel(viewModel.metaText)
    }

    private func processingCover(_ progress: Double) -> some View {
        CSSLinearGradient(degrees: 160, colors: [Color(hex: 0x3A322A), Color(hex: 0x1F1B17)])
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(RSColor.paper.opacity(0.15))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(RSColor.amber).frame(width: proxy.size.width * progress)
                        }
                    }
                    .clipShape(Capsule())
                    .padding(16)
            }
            .opacity(0.82)
    }
}
