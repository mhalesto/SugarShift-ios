import CoreGraphics

/// Traces the boundary of the active cell union, including holes. The same
/// level mask drives the well, its rim and combo clipping; it never fills the
/// rectangular envelope of a shaped board.
enum BoardContour {
    private struct Vertex: Hashable { let x: Int; let y: Int }
    private struct Edge: Hashable { let a: Vertex; let b: Vertex
        var direction: Int { b.x > a.x ? 0 : b.y > a.y ? 1 : b.x < a.x ? 2 : 3 }
    }

    static func path(mask: [[Bool]], frame: CGRect, tileSize: CGFloat, gap: CGFloat,
                     rounded: Bool = true) -> CGPath {
        let rows = mask.count, columns = mask.first?.count ?? 0
        guard rows > 0, columns > 0, mask.allSatisfy({ $0.count == columns }) else {
            return CGMutablePath()
        }
        func active(_ r: Int, _ c: Int) -> Bool {
            (0..<rows).contains(r) && (0..<columns).contains(c) && mask[r][c]
        }
        var edges: Set<Edge> = []
        for r in 0..<rows {
            for c in 0..<columns where active(r, c) {
                let tl = Vertex(x: c, y: r), tr = Vertex(x: c + 1, y: r)
                let bl = Vertex(x: c, y: r + 1), br = Vertex(x: c + 1, y: r + 1)
                if !active(r - 1, c) { edges.insert(Edge(a: tl, b: tr)) }
                if !active(r, c + 1) { edges.insert(Edge(a: tr, b: br)) }
                if !active(r + 1, c) { edges.insert(Edge(a: br, b: bl)) }
                if !active(r, c - 1) { edges.insert(Edge(a: bl, b: tl)) }
            }
        }
        let adjacency = Dictionary(grouping: edges, by: \.a)
        let result = CGMutablePath()
        let pitch = tileSize + gap
        func point(_ v: Vertex) -> CGPoint {
            CGPoint(x: frame.minX - gap / 2 + CGFloat(v.x) * pitch,
                    y: frame.maxY + gap / 2 - CGFloat(v.y) * pitch)
        }
        while let first = edges.min(by: { ($0.a.y, $0.a.x, $0.direction) < ($1.a.y, $1.a.x, $1.direction) }) {
            var loop: [Vertex] = [], edge = first
            repeat {
                loop.append(edge.a)
                edges.remove(edge)
                if edge.b == first.a { break }
                // At diagonal contacts take the tight right turn, preserving
                // distinct outlines instead of bridging across inactive cells.
                let next = (adjacency[edge.b] ?? []).filter { edges.contains($0) }
                let order = [1, 0, 3, 2]
                guard let candidate = next.min(by: {
                    order.firstIndex(of: ($0.direction - edge.direction + 4) % 4)!
                        < order.firstIndex(of: ($1.direction - edge.direction + 4) % 4)!
                }) else { break }
                edge = candidate
            } while !edges.isEmpty
            guard loop.count >= 4 else { continue }
            // Keep just corners; straight tile junctions share one clean edge.
            let corners = loop.indices.filter { i in
                let a = loop[(i + loop.count - 1) % loop.count], b = loop[i], c = loop[(i + 1) % loop.count]
                return (b.x - a.x) * (c.y - b.y) != (b.y - a.y) * (c.x - b.x)
            }.map { point(loop[$0]) }
            let radius = rounded ? min(9, tileSize * 0.19) : 0
            for i in corners.indices {
                let a = corners[(i + corners.count - 1) % corners.count], b = corners[i], c = corners[(i + 1) % corners.count]
                let before = hypot(b.x - a.x, b.y - a.y), after = hypot(c.x - b.x, c.y - b.y)
                let trim = min(radius, min(before, after) / 2)
                let entry = CGPoint(x: b.x + (a.x - b.x) * trim / before, y: b.y + (a.y - b.y) * trim / before)
                let exit = CGPoint(x: b.x + (c.x - b.x) * trim / after, y: b.y + (c.y - b.y) * trim / after)
                if i == 0 { result.move(to: entry) } else { result.addLine(to: entry) }
                result.addQuadCurve(to: exit, control: b)
            }
            result.closeSubpath()
        }
        return result
    }
}
