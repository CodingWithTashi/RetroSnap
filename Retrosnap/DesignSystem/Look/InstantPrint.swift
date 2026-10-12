import CoreGraphics

/// The Instant print as the design draws it: 88 wide by 107 tall, with `padding: 5.5% 5.5% 22% 5.5%` of its
/// width as the white frame. The screen and the saved file both take it from here, so they cannot drift apart.
nonisolated enum InstantPrint {
    static let size = CGSize(width: 88, height: 107)
    /// The frame at the sides and the top, as a fraction of the print's width.
    static let side: CGFloat = 0.055
    /// The wider strip at the bottom, as a fraction of the print's width.
    static let bottom: CGFloat = 0.22
    /// The width the Viewer gives a print.
    static let viewerWidth: CGFloat = 340
}
