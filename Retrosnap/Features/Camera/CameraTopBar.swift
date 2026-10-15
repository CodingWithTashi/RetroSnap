import SwiftUI

/// The row over the viewfinder: flash, the Photo/Video pill or the recording clock, and the self-timer.
struct CameraTopBar: View {
    let viewModel: CameraViewModel
    @State private var pulse = false

    var body: some View {
        HStack {
            GlassIconButton(
                icon: viewModel.flash == .off ? .boltSlash : .bolt, label: viewModel.flashLabel,
                iconColor: viewModel.flash == .on ? RSColor.amber : RSColor.paper, action: viewModel.flashTapped
            ) {
                if viewModel.flash == .auto {
                    badge("A").padding(.trailing, 5).padding(.bottom, 5)
                }
            }

            Spacer(minLength: 0)

            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 0.25 : 1)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                    Text(viewModel.recordingClock)
                        .rsText(.labelSmall.tabularDigits())
                        .foregroundStyle(RSColor.paper)
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(RSColor.record, in: Capsule())
                .onAppear { pulse = true }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.recordingLabel)
            } else {
                SegmentedPill(
                    options: CaptureMode.allCases.map { ($0, $0.title) },
                    selection: viewModel.mode,
                    onSelect: viewModel.select
                )
            }

            Spacer(minLength: 0)

            GlassIconButton(
                icon: .timer, label: viewModel.timerLabel,
                iconColor: viewModel.isTimerOn ? RSColor.amber : RSColor.paper, action: viewModel.timerTapped
            ) {
                if viewModel.isTimerOn {
                    badge(viewModel.timerBadge).foregroundStyle(RSColor.amber).padding(.trailing, 3).padding(.bottom, 4)
                }
            }
        }
        .frame(height: 44)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .accessibilityHidden(true)
    }
}
