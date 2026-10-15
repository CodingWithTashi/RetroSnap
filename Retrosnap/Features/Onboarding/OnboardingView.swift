import SwiftUI

/// Shows the current onboarding step. Steps slide like a push but there is no way back, as in the design.
struct OnboardingView: View {
    let step: OnboardingStep
    let viewModel: OnboardingViewModel
    let stamp: PhotoStampText

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView(stamp: stamp, onContinue: viewModel.continueTapped)
            case .howItWorks:
                HowItWorksView(stamp: stamp, chooseCameraDetail: viewModel.chooseCameraDetail, onContinue: viewModel.continueTapped)
            case .cameraPermission, .photosPermission:
                PermissionView(
                    content: viewModel.permission(for: step),
                    onAllow: viewModel.allowTapped,
                    onNotNow: viewModel.notNowTapped
                )
            }
        }
        .id(step)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
}

private struct WelcomeView: View {
    let stamp: PhotoStampText
    let onContinue: () -> Void
    @Environment(\.designLayout) private var layout

    var body: some View {
        ZStack(alignment: .top) {
            RSColor.ink
            PhotoLookView(image: .sample(.welcomeHero), camera: .film, stamp: stamp, stampBottom: 0.22)
                .frame(height: 560)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [RSColor.ink(0), RSColor.ink], startPoint: .top, endPoint: .bottom)
                        .frame(height: 220)
                }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    LogoMark()
                    Text("RetroSnap")
                        .rsText(.wordmark)
                        .foregroundStyle(RSColor.paper)
                }
                .frame(height: 34)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("Vintage photos, straight from the\ncamera. No editing needed.")
                    .rsText(.body.lineHeight(1.4).multiline())
                    .foregroundStyle(RSColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                Spacer(minLength: 0)
                PrimaryButton(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 32)
            .padding(.top, 520)
            .padding(.bottom, layout.bottom(44))
        }
        .ignoresSafeArea()
    }
}

/// The amber lens mark beside the wordmark.
private struct LogoMark: View {
    var body: some View {
        Circle()
            .fill(RSColor.amber)
            .frame(width: 30, height: 30)
            .overlay {
                Circle().fill(RSColor.ink(0.25)).frame(width: 18, height: 18)
                Circle().fill(RSColor.ink).frame(width: 12, height: 12)
            }
            .accessibilityHidden(true)
    }
}

private struct HowItWorksView: View {
    let stamp: PhotoStampText
    let chooseCameraDetail: String
    let onContinue: () -> Void
    @Environment(\.designLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Three taps to a").rsText(.title.lineHeight(1.15).tracking(-0.01))
                Text("vintage photo").rsText(.title.lineHeight(1.15).tracking(-0.01))
            }
            .foregroundStyle(RSColor.paper)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 14) {
                StepCard(number: 1, title: "Choose a camera", detail: chooseCameraDetail) {
                    cameraGrid
                }
                StepCard(number: 2, title: "Take a photo", detail: "What you see is what you get.") {
                    Image(SampleImage.tile(1016).full)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .overlay(alignment: .bottom) {
                            Circle()
                                .fill(RSColor.paper)
                                .frame(width: 22, height: 22)
                                .frame(width: 34, height: 34)
                                .overlay { Circle().strokeBorder(RSColor.amber, lineWidth: 3) }
                                .padding(.bottom, 10)
                        }
                }
                StepCard(number: 3, title: "Get the vintage look", detail: "Saved to Photos automatically.") {
                    PhotoLookView(image: .sample(.tile(1016)), camera: .film, stamp: stamp)
                }
            }
            .padding(.top, 28)

            Spacer(minLength: 0)
            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, 24)
        .padding(.top, layout.top(96))
        .padding(.bottom, layout.bottom(44))
        .background(RSColor.ink)
        .ignoresSafeArea()
    }

    /// Four looks in a 2x2 grid; the outer corners follow the tile's 16pt radius.
    private var cameraGrid: some View {
        let cells: [(Int, CameraStyle, UnevenRoundedRectangle)] = [
            (1015, .film, .init(topLeadingRadius: 12, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 4)),
            (237, .disposable, .init(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 12)),
            (1027, .instant, .init(topLeadingRadius: 4, bottomLeadingRadius: 12, bottomTrailingRadius: 4, topTrailingRadius: 4)),
            (1039, .camcorder, .init(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 12, topTrailingRadius: 4)),
        ]
        return LazyVGrid(columns: [GridItem(.fixed(47.5), spacing: 3), GridItem(.fixed(47.5))], spacing: 3) {
            ForEach(cells, id: \.0) { cell in
                PhotoLookView(image: .sample(.tile(cell.0)), camera: cell.1)
                    .frame(width: 47.5, height: 47.5)
                    .clipShape(cell.2)
            }
        }
        .frame(width: 104, height: 104)
        .background(RSColor.raised)
    }
}

private struct StepCard<Thumbnail: View>: View {
    let number: Int
    let title: String
    let detail: String
    @ViewBuilder var thumbnail: Thumbnail

    var body: some View {
        HStack(spacing: 16) {
            thumbnail
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: RSRadius.card))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(number)")
                    .rsText(.text(13, .semibold))
                    .foregroundStyle(RSColor.amber)
                Text(title)
                    .rsText(.label)
                    .foregroundStyle(RSColor.paper)
                Text(detail)
                    .rsText(.caption.lineHeight(1.35).multiline())
                    .foregroundStyle(RSColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RSColor.surface, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionView: View {
    let content: PermissionContent
    let onAllow: () -> Void
    let onNotNow: () -> Void
    @Environment(\.designLayout) private var layout

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                iconDisc
                Text(content.title)
                    .rsText(.title.lineHeight(1.15).tracking(-0.01))
                    .foregroundStyle(RSColor.paper)
                    .accessibilityAddTraits(.isHeader)
                Text(content.message)
                    .rsText(.body.lineHeight(1.4).multiline())
                    .foregroundStyle(RSColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                PrimaryButton(title: content.actionTitle, action: onAllow)
                QuietButton(title: "Not now", fillsWidth: true, action: onNotNow)
                    .opacity(content.offersNotNow ? 1 : 0)
                    .disabled(!content.offersNotNow)
                    .accessibilityHidden(!content.offersNotNow)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, layout.bottom(44))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RSColor.ink)
        .ignoresSafeArea()
    }

    private var iconDisc: some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color(hex: 0x2C2722), RSColor.surface],
                center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 103.1
            ))
            .frame(width: 132, height: 132)
            .background {
                // box-shadow: 0 0 0 10px amber 8%, 0 0 0 22px amber 4%
                Circle().fill(RSColor.amber.opacity(0.04)).padding(-22)
                Circle().fill(RSColor.amber.opacity(0.08)).padding(-10)
            }
            .overlay {
                RSIconView(content.icon, size: 56, lineWidth: 1.6)
                    .foregroundStyle(RSColor.amber)
            }
            .accessibilityHidden(true)
    }
}
