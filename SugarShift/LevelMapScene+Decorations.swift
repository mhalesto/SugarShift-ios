import SpriteKit

// Per-frame update, wave animation, decoration factories
extension LevelMapScene {
    // MARK: - Per-frame update (momentum + parallax + waves)

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastFrameTime > 0 {
            dt = CGFloat(min(currentTime - lastFrameTime, 0.05))
        } else { dt = 0 }
        lastFrameTime = currentTime

        applyMomentumAndElastic(dt: dt)
        applyParallax()
        animateWaves(dt: dt, time: currentTime)
        if currentTime >= nextHUDRefreshAt {
            nextHUDRefreshAt = currentTime + 1
            refreshHUD()
        }
    }

    func applyMomentumAndElastic(dt: CGFloat) {
        guard !isDragging else { return }

        // Free-roll deceleration (low friction = wheel feel)
        if abs(velocity) > velocityCutoff {
            world.position.y += velocity * dt
            // Apply exponential decay: v *= friction^dt
            velocity *= pow(frictionPerSecond, dt)
            if abs(velocity) < velocityCutoff { velocity = 0 }
        }

        // Elastic snap-back if outside bounds
        let y = world.position.y
        if y > worldYMax {
            let overshoot = y - worldYMax
            let pull = overshoot * (1 - exp(-elasticReturnSpeed * dt))
            world.position.y = y - pull
            // Damp velocity when pulled back
            velocity *= 0.5
        } else if y < worldYMin {
            let overshoot = worldYMin - y
            let pull = overshoot * (1 - exp(-elasticReturnSpeed * dt))
            world.position.y = y + pull
            velocity *= 0.5
        }
    }

    /// Subtle parallax — the far/mid background nodes move at a fraction of the world's Y.
    func applyParallax() {
        // bgFar moves 0.6×, bgMid moves 0.85×. We achieve this by offsetting their Y
        // relative to the world to make them lag behind during scrolls.
        let baseY = world.position.y
        bgFar.position = CGPoint(x: 0, y: -baseY * 0.40)   // counter 60% so they appear slower
        bgMid.position = CGPoint(x: 0, y: -baseY * 0.15)
    }

    // MARK: - Wave animation

    func animateWaves(dt: CGFloat, time: TimeInterval) {
        // Each wave layer drifts sideways at its own speed and wraps.
        for layer in waveLayers {
            var x = layer.node.position.x + layer.speed * dt
            let span = layer.widthSpan / 2
            if x > span { x -= layer.widthSpan }
            if x < -span { x += layer.widthSpan }
            layer.node.position.x = x
        }
    }

    // MARK: - Decoration factories

    func makeTree(color: UIColor, radius: CGFloat) -> SKNode {
        let node = SKNode()

        // Trunk — sturdier brown
        let trunk = SKShapeNode(rectOf: CGSize(width: radius * 0.34, height: radius * 0.55),
                                 cornerRadius: 5)
        trunk.fillColor = UIColor(hex: "#A06A4A")
        trunk.strokeColor = UIColor(hex: "#7B4E33").withAlphaComponent(0.7)
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: -radius * 0.85)
        node.addChild(trunk)

        // Soft drop shadow under crown
        let shadow = SKShapeNode(ellipseOf: CGSize(width: radius * 1.7,
                                                    height: radius * 0.26))
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -radius * 1.05)
        node.addChild(shadow)

        // Outer crown — slightly darker, big and puffy
        let outerColor = darken(color, by: 0.06)
        for off: (CGFloat, CGFloat, CGFloat) in [
            (-radius * 0.55,  radius * 0.05, 0.78),
            ( radius * 0.55,  radius * 0.05, 0.78),
            (-radius * 0.18, -radius * 0.18, 0.72),
            ( radius * 0.18, -radius * 0.18, 0.72),
            (0,                radius * 0.42, 1.05)
        ] {
            let c = SKShapeNode(circleOfRadius: radius * off.2)
            c.fillColor = outerColor
            c.strokeColor = .clear
            c.position = CGPoint(x: off.0, y: off.1)
            node.addChild(c)
        }

        // Inner lighter crown for that cherry-blossom highlight
        let lighter = lighten(color, by: 0.10)
        for off: (CGFloat, CGFloat, CGFloat) in [
            (-radius * 0.30, radius * 0.30, 0.45),
            ( radius * 0.30, radius * 0.30, 0.45),
            (0,               radius * 0.55, 0.45)
        ] {
            let c = SKShapeNode(circleOfRadius: radius * off.2)
            c.fillColor = lighter
            c.strokeColor = .clear
            c.position = CGPoint(x: off.0, y: off.1)
            node.addChild(c)
        }

        // Top highlight oval
        let hi = SKShapeNode(ellipseOf: CGSize(width: radius * 0.7, height: radius * 0.25))
        hi.fillColor = UIColor.white.withAlphaComponent(0.45)
        hi.strokeColor = .clear
        hi.position = CGPoint(x: -radius * 0.12, y: radius * 0.65)
        node.addChild(hi)

        // White daisies sprinkled on top of the crown
        let daisyCount = max(2, Int(radius / 16))
        for _ in 0..<daisyCount {
            let daisy = makeDaisy()
            daisy.setScale(0.8)
            daisy.position = CGPoint(
                x: CGFloat.random(in: -radius * 0.7 ... radius * 0.7),
                y: CGFloat.random(in: radius * 0.05 ... radius * 0.7)
            )
            daisy.zPosition = 1
            node.addChild(daisy)
        }

        return node
    }

    func darken(_ c: UIColor, by f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(0, r - f), green: max(0, g - f),
                        blue: max(0, b - f), alpha: a)
    }

    func lighten(_ c: UIColor, by f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r + f), green: min(1, g + f),
                        blue: min(1, b + f), alpha: a)
    }

    func makeGrassTuft() -> SKNode {
        let node = SKNode()
        for i in 0..<3 {
            let blade = SKShapeNode(rectOf: CGSize(width: 3, height: 10),
                                     cornerRadius: 1.5)
            blade.fillColor = UIColor(hex: "#16A34A").withAlphaComponent(0.85)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: CGFloat(i - 1) * 4, y: 0)
            blade.zRotation = CGFloat(i - 1) * 0.18
            node.addChild(blade)
        }
        return node
    }

    func makeDaisy() -> SKNode {
        let node = SKNode()
        for i in 0..<5 {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 5, height: 9))
            petal.fillColor = .white
            petal.strokeColor = .clear
            petal.zRotation = CGFloat(i) * (.pi * 2 / 5)
            petal.position = CGPoint(x: 0, y: 4)
            node.addChild(petal)
        }
        let core = SKShapeNode(circleOfRadius: 2.4)
        core.fillColor = UIColor(hex: "#FACC15")
        core.strokeColor = .clear
        node.addChild(core)
        node.alpha = 0.9
        return node
    }

    func makeLampPost() -> SKNode {
        let node = SKNode()
        let post = SKShapeNode(rectOf: CGSize(width: 4, height: 70), cornerRadius: 2)
        post.fillColor = UIColor(hex: "#5BA9C7")
        post.strokeColor = .clear
        node.addChild(post)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = UIColor(hex: "#FFE4F0")
        head.strokeColor = UIColor(hex: "#F472B6")
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 36)
        node.addChild(head)

        // Stripes
        let stripe1 = SKShapeNode(rectOf: CGSize(width: 4, height: 6))
        stripe1.fillColor = UIColor(hex: "#F472B6")
        stripe1.strokeColor = .clear
        stripe1.position = CGPoint(x: 0, y: -8)
        node.addChild(stripe1)
        return node
    }

    func makeCloud() -> SKNode {
        let node = SKNode()
        let radii: [CGFloat] = [22, 28, 22, 18]
        var x: CGFloat = -30
        for r in radii {
            let c = SKShapeNode(circleOfRadius: r)
            c.fillColor = UIColor.white.withAlphaComponent(0.9)
            c.strokeColor = .clear
            c.position = CGPoint(x: x, y: CGFloat.random(in: -3...3))
            node.addChild(c)
            x += r * 0.9
        }
        return node
    }

    func makeStone(width: CGFloat, height: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        body.fillColor = UIColor(hex: "#FFE4C7")
        body.strokeColor = UIColor(hex: "#FCD9C8")
        body.lineWidth = 1.5
        node.addChild(body)
        // Highlight
        let hl = SKShapeNode(ellipseOf: CGSize(width: width * 0.4, height: height * 0.3))
        hl.fillColor = UIColor.white.withAlphaComponent(0.7)
        hl.strokeColor = .clear
        hl.position = CGPoint(x: -width * 0.15, y: height * 0.15)
        node.addChild(hl)
        return node
    }

    func makeBridge(width: CGFloat, height: CGFloat) -> SKNode {
        let node = SKNode()

        // Shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: width + 4, height: height + 4),
                                  cornerRadius: 8)
        shadow.fillColor = UIColor(white: 0, alpha: 0.20)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        node.addChild(shadow)

        // Main body
        let body = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                cornerRadius: 8)
        body.fillColor = UIColor(hex: "#92765C")
        body.strokeColor = UIColor(hex: "#6B4F3A")
        body.lineWidth = 2
        node.addChild(body)

        // Plank lines
        for i in 0..<6 {
            let y = -height / 2 + 18 + CGFloat(i) * (height - 36) / 5
            let plank = SKShapeNode(rectOf: CGSize(width: width - 14, height: 2),
                                     cornerRadius: 1)
            plank.fillColor = UIColor(hex: "#6B4F3A").withAlphaComponent(0.7)
            plank.strokeColor = .clear
            plank.position = CGPoint(x: 0, y: y)
            node.addChild(plank)
        }

        // Corner bolts
        for x: CGFloat in [-width / 2 + 6, width / 2 - 6] {
            for y: CGFloat in [-height / 2 + 6, height / 2 - 6] {
                let bolt = SKShapeNode(circleOfRadius: 2.5)
                bolt.fillColor = UIColor(hex: "#FACC15")
                bolt.strokeColor = .clear
                bolt.position = CGPoint(x: x, y: y)
                node.addChild(bolt)
            }
        }
        return node
    }

    func makeWaveRibbon(width: CGFloat,
                                amplitude: CGFloat,
                                wavelength: CGFloat,
                                thickness: CGFloat,
                                color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        let steps = Int(width / 4)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = -width / 2 + t * width
            let y = sin(t * .pi * 2 * (width / wavelength)) * amplitude
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        let line = SKShapeNode(path: path.cgPath)
        line.strokeColor = color
        line.lineWidth = thickness
        line.lineCap = .round
        line.fillColor = .clear
        return line
    }

    func spawnRipple(in parent: SKNode, width: CGFloat, height: CGFloat) {
        let ripple = SKShapeNode(circleOfRadius: 4)
        ripple.fillColor = .clear
        ripple.strokeColor = UIColor.white.withAlphaComponent(0.85)
        ripple.lineWidth = 1.2
        ripple.position = CGPoint(
            x: CGFloat.random(in: -width / 2 + 30 ... width / 2 - 30),
            y: CGFloat.random(in: -height / 2 + 10 ... height / 2 - 10))
        ripple.alpha = 0.9
        parent.addChild(ripple)
        ripple.run(.sequence([
            .group([.scale(to: 4.0, duration: 1.4),
                    .fadeOut(withDuration: 1.4)]),
            .removeFromParent()
        ]))
    }

    func makeLollipopTree(side: CGFloat, color: UIColor = UIColor(hex: "#F472B6")) -> SKNode {
        let node = SKNode()
        // Trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: 14, height: 110),
                                 cornerRadius: 6)
        trunk.fillColor = UIColor(hex: "#A06A4A")
        trunk.strokeColor = UIColor(hex: "#7B4E33")
        trunk.lineWidth = 2
        trunk.position = CGPoint(x: 0, y: -55)
        node.addChild(trunk)

        // Lolly head
        let head = SKShapeNode(circleOfRadius: 56)
        head.fillColor = color
        head.strokeColor = UIColor(hex: "#BE185D").withAlphaComponent(0.5)
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 26)
        node.addChild(head)

        // Swirl on head
        let swirl = SKShapeNode(path: makeSwirlPath(maxRadius: 42).cgPath)
        swirl.strokeColor = UIColor.white.withAlphaComponent(0.6)
        swirl.lineWidth = 6
        swirl.fillColor = .clear
        swirl.lineCap = .round
        swirl.position = CGPoint(x: 0, y: 26)
        node.addChild(swirl)

        // Highlight
        let hl = SKShapeNode(ellipseOf: CGSize(width: 32, height: 14))
        hl.fillColor = UIColor.white.withAlphaComponent(0.55)
        hl.strokeColor = .clear
        hl.position = CGPoint(x: -16, y: 50)
        node.addChild(hl)

        // Gentle sway
        node.zRotation = side * 0.04
        node.run(.repeatForever(.sequence([
            .rotate(toAngle: side * 0.06, duration: 2.4),
            .rotate(toAngle: side * 0.02, duration: 2.4)
        ])))
        return node
    }

    func makeSwirlPath(maxRadius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let turns: CGFloat = 2.8
        let steps = 80
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let r = maxRadius * t
            let theta = t * turns * 2 * .pi
            let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    func makeSwirlCandy(radius: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = UIColor(hex: "#FFE4F0")
        body.strokeColor = UIColor(hex: "#F472B6")
        body.lineWidth = 1.5
        node.addChild(body)
        let swirl = SKShapeNode(path: makeSwirlPath(maxRadius: radius * 0.85).cgPath)
        swirl.strokeColor = UIColor(hex: "#F472B6")
        swirl.lineWidth = 1.5
        swirl.fillColor = .clear
        node.addChild(swirl)
        return node
    }

    func makeGumballBush() -> SKNode {
        let node = SKNode()
        let palette = [UIColor(hex: "#F472B6"),
                       UIColor(hex: "#A78BFA"),
                       UIColor(hex: "#34D399"),
                       UIColor(hex: "#FBBF24"),
                       UIColor(hex: "#60A5FA")]
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (-22, 0, 14), (22, 0, 14), (0, 12, 16),
            (-12, -8, 10), (12, -8, 10)
        ]
        for (x, y, r) in positions {
            let ball = SKShapeNode(circleOfRadius: r)
            ball.fillColor = palette.randomElement()!
            ball.strokeColor = UIColor(white: 0, alpha: 0.2)
            ball.lineWidth = 1
            ball.position = CGPoint(x: x, y: y)
            node.addChild(ball)
            // White hi
            let hi = SKShapeNode(ellipseOf: CGSize(width: r * 0.8, height: r * 0.4))
            hi.fillColor = UIColor.white.withAlphaComponent(0.5)
            hi.strokeColor = .clear
            hi.position = CGPoint(x: x - r * 0.3, y: y + r * 0.4)
            node.addChild(hi)
        }
        return node
    }

    func makeFloss() -> SKNode {
        let node = SKNode()
        // Stick
        let stick = SKShapeNode(rectOf: CGSize(width: 4, height: 30), cornerRadius: 2)
        stick.fillColor = UIColor(hex: "#A06A4A")
        stick.strokeColor = .clear
        stick.position = CGPoint(x: 0, y: -30)
        node.addChild(stick)
        // Fluff: layered translucent ovals
        for i in 0..<5 {
            let r = CGFloat(40 - i * 4)
            let c = SKShapeNode(circleOfRadius: r)
            c.fillColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.5)
            c.strokeColor = .clear
            c.position = CGPoint(x: CGFloat.random(in: -8...8), y: CGFloat(i) * 4)
            node.addChild(c)
        }
        return node
    }

    func makeHeartShape(size: CGFloat) -> SKNode {
        let node = SKNode()
        let path = UIBezierPath()
        let s = size
        path.move(to: CGPoint(x: 0, y: -s * 0.4))
        path.addCurve(to: CGPoint(x: -s * 0.5, y: s * 0.18),
                      controlPoint1: CGPoint(x: -s * 0.3, y: -s * 0.25),
                      controlPoint2: CGPoint(x: -s * 0.5, y: -s * 0.05))
        path.addArc(withCenter: CGPoint(x: -s * 0.25, y: s * 0.18),
                    radius: s * 0.25,
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: true)
        path.addArc(withCenter: CGPoint(x: s * 0.25, y: s * 0.18),
                    radius: s * 0.25,
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: true)
        path.addCurve(to: CGPoint(x: 0, y: -s * 0.4),
                      controlPoint1: CGPoint(x: s * 0.5, y: -s * 0.05),
                      controlPoint2: CGPoint(x: s * 0.3, y: -s * 0.25))
        path.close()
        let body = SKShapeNode(path: path.cgPath)
        body.fillColor = UIColor(hex: "#EC4899")
        body.strokeColor = .white
        body.lineWidth = 1.5
        node.addChild(body)
        return node
    }

    func makeGoldBarShape(size: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: size, height: size * 0.6),
                                cornerRadius: 3)
        body.fillColor = UIColor(hex: "#FBBF24")
        body.strokeColor = UIColor(hex: "#92400E")
        body.lineWidth = 1.5
        node.addChild(body)
        // Bevel highlight on top
        let hl = SKShapeNode(rectOf: CGSize(width: size * 0.7, height: 2),
                              cornerRadius: 1)
        hl.fillColor = UIColor.white.withAlphaComponent(0.6)
        hl.strokeColor = .clear
        hl.position = CGPoint(x: 0, y: size * 0.18)
        node.addChild(hl)
        return node
    }
}
