import SwiftUI

/// Everything a frame draws around its picture: the film with its perforations and edge print, the mount with
/// its card and window, or the rebate with its frame numbers. The window is left clear, so this is laid over
/// the picture. The screen draws it as a view and the exporter rasterises the same view at the file's scale,
/// so the two cannot drift apart. The strip and the 6×7 rebate are drawn lying down and turned a quarter
/// anticlockwise for a portrait canvas, the way the reference app turns them.
struct LookFrameView: View {
    let frame: LookFrame
    let size: CGSize
    /// The photo's own shape: which way the slide mount's window turns.
    var photoAspect: CGFloat = Photo.cameraAspect
    /// Which of the square print's and the slide mount's cards this photo gets.
    var design = FrameDesign()

    var body: some View {
        switch frame {
        case .fullFrame:
            // Nothing at all: the picture is the whole canvas.
            EmptyView()
        case .filmStrip, .slideMount, .mediumFormat, .square, .instantPrint, .squarePrint:
            Canvas(rendersAsynchronously: false) { context, _ in
                var context = context
                switch frame {
                case .filmStrip:
                    turnedForPortrait(&context) { context, canvas in
                        FilmStripArt(geometry: FilmStripGeometry(canvas: canvas)).draw(in: &context)
                    }
                case .mediumFormat:
                    turnedForPortrait(&context) { context, canvas in
                        SevenRebateArt(geometry: RebateGeometry.seven(in: canvas)).draw(in: &context)
                    }
                case .square:
                    SquareRebateArt(geometry: RebateGeometry.square(in: size)).draw(in: &context)
                case .slideMount:
                    SlideMountArt(geometry: SlideMountGeometry(canvas: size, photoAspect: photoAspect, design: design.slide)).draw(in: &context)
                case .instantPrint:
                    MiniPrintArt(geometry: MiniPrintGeometry(canvas: size)).draw(in: &context)
                case .squarePrint:
                    SquarePrintArt(geometry: SquarePrintGeometry(canvas: size), design: design.square).draw(in: &context)
                case .fullFrame:
                    break
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Draws the landscape artwork; a portrait canvas gets it turned a quarter anticlockwise, so the landscape
    /// bottom edge becomes the right edge.
    private func turnedForPortrait(_ context: inout GraphicsContext, draw: (inout GraphicsContext, CGSize) -> Void) {
        if size.width >= size.height {
            draw(&context, size)
        } else {
            context.translateBy(x: 0, y: size.height)
            context.rotate(by: .degrees(-90))
            draw(&context, CGSize(width: size.height, height: size.width))
        }
    }
}
