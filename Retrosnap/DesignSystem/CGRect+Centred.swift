import CoreGraphics

extension CGRect {
    /// A rectangle of `size` centred in a box of `canvas`, measured from the box's top-left corner.
    nonisolated init(centredIn canvas: CGSize, size: CGSize) {
        self.init(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }

    /// The square a circle of `radius` around `centre` is drawn in (`Path(ellipseIn:)`, `addEllipse(in:)`).
    nonisolated init(centre: CGPoint, radius: CGFloat) {
        self.init(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
    }
}
