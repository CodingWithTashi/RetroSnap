import UIKit

/// CSS `text-wrap: pretty` for body text: keeps the number of lines but evens out their lengths
/// by finding the narrowest width that does not add a line.
enum BalancedWrap {
    static func width(for text: String, fontSize: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize)
        func lines(_ width: CGFloat) -> Int {
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil
            )
            return Int((bounds.height / font.lineHeight).rounded())
        }
        let target = lines(maxWidth)
        guard target > 1 else { return maxWidth }
        var low = maxWidth / 2, high = maxWidth
        while high - low > 1 {
            let middle = (low + high) / 2
            if lines(middle) > target { low = middle } else { high = middle }
        }
        return high.rounded(.up)
    }
}
