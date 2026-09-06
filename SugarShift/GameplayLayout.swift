import CoreGraphics

/// Logical, safe-area-aware composition. Artboard proportions guide the shell;
/// the board independently fits its rows and columns into the remaining space.
struct GameplayLayout {
    let scale: CGFloat
    let brand: CGRect
    let levelCard: CGRect
    let board: CGRect
    let utility: CGRect
    let boosters: CGRect
    let navigation: CGRect
    let tileSize: CGFloat
    let gap: CGFloat

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, rows: Int, columns: Int) {
        let width = min(540, max(1, size.width - 28))
        scale = min(1.2, max(0.70, size.width / 393))
        let top = size.height / 2 - safeTop - 5
        let bottom = -size.height / 2 + safeBottom + 5
        let available = max(1, top - bottom)
        let compact = min(1, available / (740 * scale))
        let s = scale * max(0.77, compact)
        let spacing = 7 * s
        func rect(y: CGFloat, h: CGFloat) -> CGRect {
            CGRect(x: -width / 2, y: y, width: width, height: h)
        }
        let navH = 48 * s, trayH = 88 * s, utilityH = 23 * s
        let cardH = 140 * s, brandH = 74 * s
        navigation = rect(y: bottom, h: navH)
        boosters = rect(y: navigation.maxY + 11 * s, h: trayH)
        utility = rect(y: boosters.maxY + spacing, h: utilityH)
        brand = rect(y: top - brandH, h: brandH)
        levelCard = rect(y: brand.minY - spacing - cardH, h: cardH)
        let regionBottom = utility.maxY + spacing
        let regionTop = levelCard.minY - 10 * s
        let regionH = max(1, regionTop - regionBottom)
        gap = max(1.2, 2.0 * scale)
        let nCols = CGFloat(max(1, columns)), nRows = CGFloat(max(1, rows))
        tileSize = max(1, min((width - 10 - gap * (nCols - 1)) / nCols,
                             (regionH - 10 - gap * (nRows - 1)) / nRows))
        let boardW = tileSize * nCols + gap * (nCols - 1)
        let boardH = tileSize * nRows + gap * (nRows - 1)
        board = CGRect(x: -boardW / 2,
                       y: (regionBottom + regionTop - boardH) / 2,
                       width: boardW, height: boardH)
    }
}

enum GamePhase: String {
    case loading, tutorial, waitingForInput, swapping, resolvingMatches
    case activatingSpecial, falling, shuffling, worldCombo, levelWon, levelFailed, paused
    var acceptsBoardInput: Bool { self == .waitingForInput || self == .tutorial }
}
