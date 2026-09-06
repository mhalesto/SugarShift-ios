import CoreGraphics
import Testing
@testable import SugarShift

struct BoardContourTests {
    @Test func steppedWellLeavesMissingCornersAndInteriorHoleOpen() {
        let mask = [[false, true, true, false], [true, true, true, true],
                    [true, false, true, true], [false, true, true, false]]
        let frame = CGRect(x: -83, y: -83, width: 166, height: 166)
        let path = BoardContour.path(mask: mask, frame: frame, tileSize: 40, gap: 2)
        for r in mask.indices {
            for c in mask[r].indices {
                let point = CGPoint(x: frame.minX + 20 + CGFloat(c) * 42,
                                    y: frame.maxY - 20 - CGFloat(r) * 42)
                #expect(path.contains(point) == mask[r][c])
            }
        }
        #expect(path.contains(CGPoint(x: -42, y: 42)), "Adjacent cells must have a continuous well")
    }

    @Test func nonSquareContourHasIndependentWidthAndHeight() {
        let mask = Array(repeating: Array(repeating: true, count: 7), count: 6)
        let path = BoardContour.path(mask: mask, frame: CGRect(x: 0, y: 0, width: 292, height: 250), tileSize: 40, gap: 2)
        #expect(path.boundingBoxOfPath.width == 294)
        #expect(path.boundingBoxOfPath.height == 252)
    }
}
