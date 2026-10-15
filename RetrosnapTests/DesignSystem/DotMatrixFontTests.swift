import Testing
@testable import Retrosnap

@MainActor
struct DotMatrixFontTests {
    @Test func theDotMatrixHasAGlyphForEveryMarkTheDateBackPrints() {
        for character in "0123456789'年月日 " {
            let glyph = DotMatrixFont.glyph(for: character)
            #expect(glyph.rows.count == 7)
            #expect(glyph.rows.allSatisfy { $0.count == glyph.width })
        }
        #expect(DotMatrixFont.glyphs(for: "'26年 10月8日").count == 10)
    }
}
