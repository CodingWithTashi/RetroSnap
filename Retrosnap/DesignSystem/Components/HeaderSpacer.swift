import SwiftUI

/// Keeps a header's title centred: an empty box as wide as the button opposite.
struct HeaderSpacer: View {
    var width: CGFloat = 44

    var body: some View {
        Color.clear.frame(width: width, height: 44)
    }
}
