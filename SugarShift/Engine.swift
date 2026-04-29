import Foundation

enum Special: String {
    case stripedRow = "striped-row"
    case stripedCol = "striped-col"
    case wrapped
    case colorBomb = "color-bomb"
    case bomb
}

enum CellKind {
    case normal
    case ingredient
}

enum BlockerType {
    case ice
    case lock
}

struct Blocker {
    var type: BlockerType
    var hits: Int
}

struct Cell {
    let id: String
    var color: String
    var special: Special?
    var kind: CellKind
}

struct Pos: Hashable {
    let r: Int
    let c: Int
}

typealias Grid = [[Cell?]]

enum Engine {
    private static func uid() -> String {
        let t = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let r = String(Int.random(in: 0..<Int(pow(36.0, 5))), radix: 36)
        return "\(t)_\(r)"
    }

    static func createInitialGrid(rows: Int, cols: Int, colors: [String], mask: [[Bool]]? = nil) -> Grid {
        var g: Grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if let m = mask, !m[r][c] { continue }
                var color: String = colors[0]
                var tries = 0
                repeat {
                    color = colors.randomElement()!
                    tries += 1
                } while tries < 12 && wouldMakeInitialMatch(g, r: r, c: c, color: color)
                g[r][c] = Cell(id: uid(), color: color, special: nil, kind: .normal)
            }
        }
        return g
    }

    static func findMatches(_ grid: Grid) -> Set<Pos> {
        let rows = grid.count
        let cols = grid[0].count
        var out = Set<Pos>()

        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let cell = grid[r][c] else { c += 1; continue }
                let color = cell.color
                var k = c + 1
                while k < cols, grid[r][k]?.color == color { k += 1 }
                if k - c >= 3 {
                    for x in c..<k { out.insert(Pos(r: r, c: x)) }
                }
                c = k
            }
        }
        for c in 0..<cols {
            var r = 0
            while r < rows {
                guard let cell = grid[r][c] else { r += 1; continue }
                let color = cell.color
                var k = r + 1
                while k < rows, grid[k][c]?.color == color { k += 1 }
                if k - r >= 3 {
                    for y in r..<k { out.insert(Pos(r: y, c: c)) }
                }
                r = k
            }
        }
        return out
    }

    @discardableResult
    static func clearMatches(_ grid: inout Grid, matches: Set<Pos>) -> Int {
        var cleared = 0
        for p in matches {
            if grid[p.r][p.c] != nil {
                grid[p.r][p.c] = nil
                cleared += 1
            }
        }
        return cleared
    }

    static func collapseAndRefill(_ grid: Grid, colors: [String], mask: [[Bool]]? = nil) -> Grid {
        let rows = grid.count
        let cols = grid[0].count
        var g = grid
        for c in 0..<cols {
            var playable: [Int] = []
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let m = mask, !m[r][c] { g[r][c] = nil; continue }
                playable.append(r)
            }
            var stack: [Cell] = []
            for r in playable { if let cell = g[r][c] { stack.append(cell) } }
            var idx = 0
            for r in playable {
                if idx < stack.count {
                    g[r][c] = stack[idx]
                    idx += 1
                } else {
                    let color = colors.randomElement()!
                    g[r][c] = Cell(id: uid(), color: color, special: nil, kind: .normal)
                }
            }
        }
        return g
    }

    /// Returns the swapped grid only if the swap creates a match at either position.
    static func swapIfValid(_ grid: Grid, _ a: Pos, _ b: Pos) -> (didSwap: Bool, grid: Grid) {
        var g = grid
        let rows = g.count, cols = g[0].count
        guard a.r >= 0, a.r < rows, a.c >= 0, a.c < cols,
              b.r >= 0, b.r < rows, b.c >= 0, b.c < cols,
              g[a.r][a.c] != nil, g[b.r][b.c] != nil else {
            return (false, grid)
        }
        let tmp = g[a.r][a.c]
        g[a.r][a.c] = g[b.r][b.c]
        g[b.r][b.c] = tmp
        if createsMatch(g, at: a) || createsMatch(g, at: b) {
            return (true, g)
        }
        return (false, grid)
    }

    static func hasAnyMoves(_ grid: Grid) -> Bool {
        let rows = grid.count, cols = grid[0].count
        for r in 0..<rows {
            for c in 0..<cols {
                let here = Pos(r: r, c: c)
                if c + 1 < cols, swapIfValid(grid, here, Pos(r: r, c: c + 1)).didSwap { return true }
                if r + 1 < rows, swapIfValid(grid, here, Pos(r: r + 1, c: c)).didSwap { return true }
            }
        }
        return false
    }

    // MARK: - helpers

    private static func wouldMakeInitialMatch(_ g: Grid, r: Int, c: Int, color: String) -> Bool {
        if c >= 2, g[r][c - 1]?.color == color, g[r][c - 2]?.color == color { return true }
        if r >= 2, g[r - 1][c]?.color == color, g[r - 2][c]?.color == color { return true }
        return false
    }

    private static func createsMatch(_ g: Grid, at p: Pos) -> Bool {
        let rows = g.count, cols = g[0].count
        guard let here = g[p.r][p.c] else { return false }
        let color = here.color

        var cnt = 1
        var x = p.c - 1
        while x >= 0, g[p.r][x]?.color == color { cnt += 1; x -= 1 }
        x = p.c + 1
        while x < cols, g[p.r][x]?.color == color { cnt += 1; x += 1 }
        if cnt >= 3 { return true }

        cnt = 1
        var y = p.r - 1
        while y >= 0, g[y][p.c]?.color == color { cnt += 1; y -= 1 }
        y = p.r + 1
        while y < rows, g[y][p.c]?.color == color { cnt += 1; y += 1 }
        return cnt >= 3
    }
}
