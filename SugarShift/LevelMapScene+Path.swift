import SpriteKit

// Grass + dirt corridor + candy ribbon path
extension LevelMapScene {
    // MARK: - Grass + dirt corridor + candy ribbon path

    /// A wide green grass underlay that covers the entire scrollable world so the
    /// path corridor sits on grass everywhere — the Candy Crush look.
    func buildGrassBackdrop() {
        guard let last = levelPositions[levelCount] else { return }
        let totalH = last.y + 800   // extra padding above the final level

        let grass = SKShapeNode(rectOf: CGSize(width: size.width * 1.4,
                                                 height: totalH + size.height))
        grass.fillColor = UIColor(hex: "#A7F3D0")
        grass.strokeColor = .clear
        grass.position = CGPoint(x: 0, y: totalH / 2 - 200)
        grass.zPosition = -20
        world.addChild(grass)

        // Subtle sun-dappled lighter horizontal bands to break up the green
        for i in 0..<6 {
            let band = SKShapeNode(rectOf: CGSize(width: size.width * 1.5, height: 80),
                                    cornerRadius: 30)
            band.fillColor = UIColor(hex: "#BBF7D0").withAlphaComponent(0.55)
            band.strokeColor = .clear
            band.position = CGPoint(
                x: CGFloat.random(in: -40...40),
                y: CGFloat(i) * (totalH / 6) + CGFloat.random(in: -50...50)
            )
            band.zPosition = -19
            world.addChild(band)
        }

        // Scatter daisies and small grass blades across the green
        let halfW = size.width / 2
        for n in 1...levelCount {
            guard let p = levelPositions[n] else { continue }
            for _ in 0..<5 {
                let daisy = makeDaisy()
                // Avoid placing daisies inside the path corridor
                let xCandidates = [
                    CGFloat.random(in: -halfW + 16 ... -halfW * 0.45),
                    CGFloat.random(in: halfW * 0.45 ... halfW - 16)
                ]
                daisy.position = CGPoint(x: xCandidates.randomElement()!,
                                          y: p.y + CGFloat.random(in: -90...90))
                daisy.zPosition = -10
                world.addChild(daisy)
            }
            for _ in 0..<4 {
                let tuft = makeGrassTuft()
                let xCandidates = [
                    CGFloat.random(in: -halfW + 10 ... -halfW * 0.40),
                    CGFloat.random(in: halfW * 0.40 ... halfW - 10)
                ]
                tuft.position = CGPoint(x: xCandidates.randomElement()!,
                                         y: p.y + CGFloat.random(in: -100...100))
                tuft.zPosition = -9
                world.addChild(tuft)
            }
        }
    }

    /// Tan dirt strip following the bezier path — the "road" beneath the candy ribbon.
    func buildPathCorridor() {
        let path = makeFullPathBezier()

        let edge = SKShapeNode(path: path.cgPath)
        edge.strokeColor = UIColor(hex: "#F0CFAA")
        edge.lineWidth = 156
        edge.lineCap = .round
        edge.lineJoin = .round
        edge.fillColor = .clear
        edge.zPosition = -6
        world.addChild(edge)

        let corridor = SKShapeNode(path: path.cgPath)
        corridor.strokeColor = UIColor(hex: "#FBE5C8")
        corridor.lineWidth = 140
        corridor.lineCap = .round
        corridor.lineJoin = .round
        corridor.fillColor = .clear
        corridor.zPosition = -5
        world.addChild(corridor)

        // Soft inner highlight
        let highlight = SKShapeNode(path: path.cgPath)
        highlight.strokeColor = UIColor(hex: "#FFE9CD")
        highlight.lineWidth = 100
        highlight.lineCap = .round
        highlight.lineJoin = .round
        highlight.fillColor = .clear
        highlight.zPosition = -4
        world.addChild(highlight)

        // Sprinkle small "pebble" decorations along the dirt strip
        for i in 1..<levelCount {
            guard let a = levelPositions[i], let b = levelPositions[i + 1] else { continue }
            let dx = b.x - a.x; let dy = b.y - a.y
            let arc = max(40, abs(dx) * 0.6)
            let dir: CGFloat = dx >= 0 ? 1 : -1
            let c1 = CGPoint(x: a.x + dir * arc, y: a.y + dy * 0.33)
            let c2 = CGPoint(x: b.x - dir * arc, y: a.y + dy * 0.66)

            for _ in 0..<2 {
                let t = CGFloat.random(in: 0.15...0.85)
                let p = bezier(a, c1, c2, b, t)
                let pNext = bezier(a, c1, c2, b, min(1, t + 0.01))
                let perpX = -(pNext.y - p.y)
                let perpY = pNext.x - p.x
                let plen = max(0.001, sqrt(perpX * perpX + perpY * perpY))
                let off = CGFloat.random(in: -55...55)
                let pebble = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 4...8),
                                                            height: CGFloat.random(in: 3...5)))
                pebble.fillColor = UIColor(hex: "#E0B589").withAlphaComponent(0.7)
                pebble.strokeColor = .clear
                pebble.position = CGPoint(x: p.x + perpX / plen * off,
                                            y: p.y + perpY / plen * off)
                pebble.zPosition = -3
                world.addChild(pebble)
            }
        }
    }

    /// Full bezier path connecting all level positions with smooth arcs.
    func makeFullPathBezier() -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = levelPositions[1] else { return path }
        path.move(to: first)
        for i in 1..<levelCount {
            guard let a = levelPositions[i], let b = levelPositions[i + 1] else { continue }
            let dx = b.x - a.x; let dy = b.y - a.y
            let arcStrength: CGFloat = max(40, abs(dx) * 0.6)
            let dir: CGFloat = (dx >= 0) ? 1 : -1
            let c1 = CGPoint(x: a.x + dir * arcStrength, y: a.y + dy * 0.33)
            let c2 = CGPoint(x: b.x - dir * arcStrength, y: a.y + dy * 0.66)
            path.addCurve(to: b, controlPoint1: c1, controlPoint2: c2)
        }
        return path
    }

    /// Big white candy-cane ribbon with diagonal pink stripes, sitting on the dirt corridor.
    func buildCandyRibbon() {
        let path = makeFullPathBezier()

        // Outer cream border for contrast against the dirt
        let outer = SKShapeNode(path: path.cgPath)
        outer.strokeColor = UIColor(hex: "#FFE4F0")
        outer.lineWidth = 56
        outer.lineCap = .round
        outer.lineJoin = .round
        outer.fillColor = .clear
        outer.zPosition = 3
        world.addChild(outer)

        // White ribbon body
        let body = SKShapeNode(path: path.cgPath)
        body.strokeColor = .white
        body.lineWidth = 48
        body.lineCap = .round
        body.lineJoin = .round
        body.fillColor = .clear
        body.zPosition = 4
        world.addChild(body)

        // Diagonal pink stripes — thin slanted bars sitting *inside* the ribbon.
        for i in 1..<levelCount {
            guard let a = levelPositions[i], let b = levelPositions[i + 1] else { continue }
            let dx = b.x - a.x; let dy = b.y - a.y
            let arc = max(40, abs(dx) * 0.6)
            let dir: CGFloat = dx >= 0 ? 1 : -1
            let c1 = CGPoint(x: a.x + dir * arc, y: a.y + dy * 0.33)
            let c2 = CGPoint(x: b.x - dir * arc, y: a.y + dy * 0.66)

            // Spacing along the bezier — ~28pt between adjacent pink stripes.
            let stripeCount = 9
            for s in 0..<stripeCount {
                let t = (CGFloat(s) + 0.5) / CGFloat(stripeCount)
                let p = bezier(a, c1, c2, b, t)
                let pNext = bezier(a, c1, c2, b, min(1.0, t + 0.005))
                let angle = atan2(pNext.y - p.y, pNext.x - p.x)

                let stripe = SKShapeNode(rectOf: CGSize(width: 6, height: 38),
                                          cornerRadius: 3)
                stripe.fillColor = UIColor(hex: "#EC4899")
                stripe.strokeColor = .clear
                stripe.position = p
                // Rotate the stripe to stand mostly across the ribbon, with a
                // light diagonal lean for the candy-cane feel.
                stripe.zRotation = angle + .pi / 2 - 0.55
                stripe.zPosition = 5
                world.addChild(stripe)
            }
        }
    }

    /// Tiny iridescent dots on the ribbon for a slight sparkle / "candy" feel.
    func buildPathDots() {
        for i in 1..<levelCount {
            guard let a = levelPositions[i], let b = levelPositions[i + 1] else { continue }
            let dx = b.x - a.x; let dy = b.y - a.y
            let arc = max(40, abs(dx) * 0.6)
            let dir: CGFloat = dx >= 0 ? 1 : -1
            let c1 = CGPoint(x: a.x + dir * arc, y: a.y + dy * 0.33)
            let c2 = CGPoint(x: b.x - dir * arc, y: a.y + dy * 0.66)

            for s in stride(from: 0.10, through: 0.90, by: 0.20) {
                let t = CGFloat(s)
                let p = bezier(a, c1, c2, b, t)
                let dot = SKShapeNode(circleOfRadius: 1.5)
                dot.fillColor = UIColor.white.withAlphaComponent(0.9)
                dot.strokeColor = .clear
                dot.position = p
                dot.zPosition = 6
                world.addChild(dot)
            }
        }
    }

    func bezier(_ p0: CGPoint, _ p1: CGPoint,
                        _ p2: CGPoint, _ p3: CGPoint,
                        _ t: CGFloat) -> CGPoint {
        let omt = 1 - t
        let x = omt*omt*omt * p0.x + 3*omt*omt*t * p1.x + 3*omt*t*t * p2.x + t*t*t * p3.x
        let y = omt*omt*omt * p0.y + 3*omt*omt*t * p1.y + 3*omt*t*t * p2.y + t*t*t * p3.y
        return CGPoint(x: x, y: y)
    }
}
