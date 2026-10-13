#if DEBUG
import SwiftUI

/// Debug-only: the design system on one screen, for checking tokens and components against the design board.
/// `-rsScreen look -rsCamera <id>` shows one look full screen instead.
struct DesignCatalogView: View {
    let arguments: [String]

    private func value(_ flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static let designStamp = PhotoStampText(date: "'26 10 11", tapeDate: "OCT 11 2026", tapeTime: "4:12 PM")

    var body: some View {
        if value("-rsScreen") == "look" {
            PhotoLookView(
                image: .sceneBack,
                camera: CameraStyle(rawValue: value("-rsCamera") ?? "film") ?? .film,
                stamp: Self.designStamp,
                stampBottom: 0.27,
                stampTop: 0.17
            )
            .ignoresSafeArea()
        } else {
            catalog
        }
    }

    private var catalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("COLOR · CORE") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        swatch("Ink", RSColor.ink)
                        swatch("Surface", RSColor.surface)
                        swatch("Raised", RSColor.raised)
                        swatch("Paper", RSColor.paper)
                        swatch("Secondary", RSColor.secondaryText)
                        swatch("Amber", RSColor.amber)
                        swatch("Record", RSColor.record)
                        swatch("Destructive", RSColor.destructive)
                    }
                }
                section("TYPE") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose a camera").rsText(.title.lineHeight(1.15))
                        Text("35mm Film · Take another").rsText(.label)
                        Text("Golden tones, fine grain, soft edges.").rsText(.body)
                        Text("Saved to Photos").rsText(.caption).foregroundStyle(RSColor.secondaryText)
                        DateStampView(text: "'26 10 11", size: 26)
                    }
                }
                section("SHUTTER · THE HERO") {
                    HStack(spacing: 4) {
                        ShutterButton(appearance: .photo, label: "Take photo") {}
                        ShutterButton(appearance: .photo, isPosed: true, label: "Pressed") {}
                        ShutterButton(appearance: .video, label: "Start recording") {}
                        ShutterButton(appearance: .recording, label: "Stop recording") {}
                    }
                }
                section("BUTTONS & CONTROLS") {
                    VStack(alignment: .leading, spacing: 12) {
                        PrimaryButton(title: "Primary · one per screen") {}
                        SecondaryButton(title: "Secondary") {}
                        HStack(spacing: 10) {
                            CircleIconButton(icon: .bolt, label: "Flash", iconSize: 22, lineWidth: 1.8, fill: RSColor.paper.opacity(0.12)) {}
                            SegmentedPill(options: [(0, "Photo"), (1, "Video")], selection: 0, style: .inset) { _ in }
                            RSSwitch(isOn: true)
                            RSSwitch(isOn: false)
                        }
                        HStack(spacing: 6) {
                            ChoiceChip(title: "Effect", isSelected: true) {}
                            ChoiceChip(title: "Grain", isSelected: false) {}
                            ChoiceChip(title: "Cream", isSelected: false, swatch: RSColor.paper) {}
                        }
                        ToastView(text: "Photo deleted", actionTitle: "Undo")
                        ToastView(text: "Saved to Photos")
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 10), spacing: 10) {
                            ForEach(RSIcon.allCases, id: \.self) { icon in
                                RSIconView(icon, size: 22)
                            }
                        }
                    }
                }
                section("THE CAMERAS") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(CameraStyle.allCases) { camera in
                            VStack(alignment: .leading, spacing: 10) {
                                PhotoLookView(image: .photo(1011), camera: camera, stamp: Self.designStamp)
                                    .aspectRatio(3 / 4, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                HStack {
                                    Text(camera.name).rsText(.label)
                                    Spacer()
                                    Text(camera.badge)
                                        .rsText(.rounded(12, .bold))
                                        .foregroundStyle(RSColor.onAccent)
                                        .padding(.horizontal, 9)
                                        .frame(height: 24)
                                        .background(Color(hex: camera.accentHex), in: Capsule())
                                }
                            }
                            .padding(10)
                            .background(Color(hex: camera.cardTintHex), in: RoundedRectangle(cornerRadius: 24))
                        }
                        PhotoLookView(image: .photo(1027), camera: .instant, framed: true, stamp: Self.designStamp)
                            .aspectRatio(88 / 107, contentMode: .fit)
                        PhotoLookView(image: .photo(1039), camera: .camcorder, stamp: Self.designStamp, videoDuration: "0:24")
                            .aspectRatio(3 / 4, contentMode: .fit)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(RSColor.paper)
        .background(RSColor.ink)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(RSColor.secondaryText)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color)
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(RSColor.paper.opacity(0.15)) }
                .frame(height: 64)
            Text(name).font(.system(size: 13, weight: .semibold))
        }
    }
}
#endif
