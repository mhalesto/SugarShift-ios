import SpriteKit

// Tab icon factories
extension LevelMapScene {
    // MARK: - Tab icon factories

    /// Folded paper map (blue) with a pink lollipop perched on top.
    func makeMapTabIcon() -> SKNode {
        let node = SKNode()

        // Drop shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: 38, height: 28),
                                  cornerRadius: 4)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        node.addChild(shadow)

        // Folded paper body — light blue with darker fold lines
        let map = SKShapeNode(rectOf: CGSize(width: 36, height: 26),
                               cornerRadius: 3)
        map.fillColor = UIColor(hex: "#7DD3FC")
        map.strokeColor = UIColor(hex: "#0284C7")
        map.lineWidth = 1.5
        node.addChild(map)

        // Fold lines (vertical creases give the accordion-fold feel)
        for x: CGFloat in [-9, 0, 9] {
            let fold = SKShapeNode(rectOf: CGSize(width: 1.2, height: 22))
            fold.fillColor = UIColor(hex: "#0284C7").withAlphaComponent(0.45)
            fold.strokeColor = .clear
            fold.position = CGPoint(x: x, y: 0)
            node.addChild(fold)
        }

        // Subtle "route" line crossing the map
        let routePath = UIBezierPath()
        routePath.move(to: CGPoint(x: -14, y: -4))
        routePath.addQuadCurve(to: CGPoint(x: 14, y: 4),
                               controlPoint: CGPoint(x: 0, y: 12))
        let route = SKShapeNode(path: routePath.cgPath)
        route.strokeColor = UIColor(hex: "#FB7185")
        route.lineWidth = 1.5
        route.lineCap = .round
        route.fillColor = .clear
        node.addChild(route)

        // Pink lollipop perched on top
        let stick = SKShapeNode(rectOf: CGSize(width: 1.5, height: 8),
                                  cornerRadius: 1)
        stick.fillColor = .white
        stick.strokeColor = UIColor(hex: "#94A3B8").withAlphaComponent(0.4)
        stick.lineWidth = 0.5
        stick.position = CGPoint(x: 0, y: 14)
        node.addChild(stick)

        let lolly = SKShapeNode(circleOfRadius: 7)
        lolly.fillColor = UIColor(hex: "#F472B6")
        lolly.strokeColor = .white
        lolly.lineWidth = 2
        lolly.position = CGPoint(x: 0, y: 21)
        node.addChild(lolly)

        let hi = SKShapeNode(ellipseOf: CGSize(width: 4, height: 2))
        hi.fillColor = UIColor.white.withAlphaComponent(0.85)
        hi.strokeColor = .clear
        hi.position = CGPoint(x: -2, y: 22)
        node.addChild(hi)

        return node
    }

    /// Cream calendar with red binder, green checkmark, and a red "1" notification.
    func makeDailyTabIcon() -> SKNode {
        let node = SKNode()

        // Sparkle background — small yellow stars behind the calendar
        for off: (CGFloat, CGFloat, CGFloat) in [(-18, 8, 0.6), (16, -10, 0.7), (-14, -12, 0.5)] {
            let s = SKLabelNode(text: "✦")
            s.fontName = "AvenirNext-Heavy"
            s.fontSize = 9 * off.2 + 6
            s.fontColor = UIColor(hex: "#FACC15")
            s.alpha = 0.85
            s.verticalAlignmentMode = .center
            s.horizontalAlignmentMode = .center
            s.position = CGPoint(x: off.0, y: off.1)
            node.addChild(s)
        }

        // Drop shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: 28, height: 30),
                                  cornerRadius: 4)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        node.addChild(shadow)

        // Calendar body (cream)
        let body = SKShapeNode(rectOf: CGSize(width: 26, height: 28),
                                 cornerRadius: 4)
        body.fillColor = UIColor(hex: "#FFFBEB")
        body.strokeColor = UIColor(hex: "#92400E")
        body.lineWidth = 1.5
        node.addChild(body)

        // Red top binder
        let binder = SKShapeNode(rectOf: CGSize(width: 26, height: 8),
                                  cornerRadius: 4)
        binder.fillColor = UIColor(hex: "#EF4444")
        binder.strokeColor = .clear
        binder.position = CGPoint(x: 0, y: 10)
        node.addChild(binder)

        // Mask the bottom of the binder so corners stay rounded only on top
        let binderHide = SKShapeNode(rectOf: CGSize(width: 26, height: 4))
        binderHide.fillColor = UIColor(hex: "#EF4444")
        binderHide.strokeColor = .clear
        binderHide.position = CGPoint(x: 0, y: 8)
        node.addChild(binderHide)

        // Two ring tabs at the top
        for x: CGFloat in [-7, 7] {
            let ring = SKShapeNode(circleOfRadius: 1.6)
            ring.fillColor = UIColor(hex: "#FFFBEB")
            ring.strokeColor = UIColor(hex: "#92400E")
            ring.lineWidth = 0.8
            ring.position = CGPoint(x: x, y: 14)
            node.addChild(ring)
        }

        // Green checkmark in the body
        let check = Icons.sprite("checkmark", size: 14, weight: .heavy,
                                  tint: UIColor(hex: "#10B981"))
        check.position = CGPoint(x: 0, y: -2)
        node.addChild(check)

        // Red "1" notification badge
        let badge = SKShapeNode(circleOfRadius: 8)
        badge.fillColor = UIColor(hex: "#EF4444")
        badge.strokeColor = .white
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: 14, y: 14)
        node.addChild(badge)

        let n = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        n.text = "1"
        n.fontSize = 11
        n.fontColor = .white
        n.verticalAlignmentMode = .center
        n.horizontalAlignmentMode = .center
        badge.addChild(n)

        return node
    }

    /// Two cartoon character heads side-by-side (one blue, one yellow).
    func makeFriendsTabIcon() -> SKNode {
        let node = SKNode()

        // Back character (blue)
        addLittleCharacter(into: node,
                            at: CGPoint(x: 5, y: -1),
                            scale: 1.0,
                            shirt: UIColor(hex: "#60A5FA"),
                            head: UIColor(hex: "#FCD34D"))

        // Front character (green/yellow accents)
        addLittleCharacter(into: node,
                            at: CGPoint(x: -7, y: 2),
                            scale: 1.0,
                            shirt: UIColor(hex: "#34D399"),
                            head: UIColor(hex: "#FED7AA"))

        return node
    }

    /// One little person — round head + smile + body. Used by the friends tab.
    func addLittleCharacter(into parent: SKNode,
                                      at p: CGPoint,
                                      scale: CGFloat,
                                      shirt: UIColor,
                                      head: UIColor) {
        let group = SKNode()
        group.position = p
        group.setScale(scale)

        // Body (rounded rectangle)
        let body = SKShapeNode(rectOf: CGSize(width: 18, height: 16),
                                 cornerRadius: 8)
        body.fillColor = shirt
        body.strokeColor = .white
        body.lineWidth = 1.5
        body.position = CGPoint(x: 0, y: -10)
        group.addChild(body)

        // Head
        let h = SKShapeNode(circleOfRadius: 8)
        h.fillColor = head
        h.strokeColor = .white
        h.lineWidth = 1.5
        h.position = CGPoint(x: 0, y: 4)
        group.addChild(h)

        // Eyes
        for ex: CGFloat in [-2.5, 2.5] {
            let eye = SKShapeNode(circleOfRadius: 1.1)
            eye.fillColor = UIColor(hex: "#0F172A")
            eye.strokeColor = .clear
            eye.position = CGPoint(x: ex, y: 5)
            group.addChild(eye)
        }
        // Smile
        let smilePath = UIBezierPath()
        smilePath.move(to: CGPoint(x: -2, y: 1))
        smilePath.addQuadCurve(to: CGPoint(x: 2, y: 1),
                                controlPoint: CGPoint(x: 0, y: -1))
        let smile = SKShapeNode(path: smilePath.cgPath)
        smile.strokeColor = UIColor(hex: "#0F172A")
        smile.lineWidth = 1.0
        smile.lineCap = .round
        smile.fillColor = .clear
        group.addChild(smile)

        parent.addChild(group)
    }

    /// Pink prize-wheel with a yellow star center and tiny sparkle.
    func makeBoostersTabIcon() -> SKNode {
        let node = SKNode()

        // Outer ring (yellow)
        let outer = SKShapeNode(circleOfRadius: 17)
        outer.fillColor = UIColor(hex: "#FBBF24")
        outer.strokeColor = .white
        outer.lineWidth = 2
        node.addChild(outer)

        // Inner pink platter
        let inner = SKShapeNode(circleOfRadius: 12)
        inner.fillColor = UIColor(hex: "#F472B6")
        inner.strokeColor = .white
        inner.lineWidth = 1.5
        node.addChild(inner)

        // Pie-slice dividers — short white lines from center
        for i in 0..<6 {
            let theta = CGFloat(i) * (.pi / 3)
            let x = cos(theta) * 12
            let yy = sin(theta) * 12
            let line = SKShapeNode(rectOf: CGSize(width: 1.5, height: 12))
            line.fillColor = UIColor.white.withAlphaComponent(0.7)
            line.strokeColor = .clear
            line.position = CGPoint(x: x / 2, y: yy / 2)
            line.zRotation = theta + .pi / 2
            node.addChild(line)
        }

        // Yellow star in the middle
        let star = SKShapeNode(path: starShapePath(size: 16))
        star.fillColor = UIColor(hex: "#FBBF24")
        star.strokeColor = UIColor(hex: "#92400E")
        star.lineWidth = 1.2
        node.addChild(star)

        // Tiny "ticker" arrow at top
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: -4, y: 18))
        arrowPath.addLine(to: CGPoint(x: 4, y: 18))
        arrowPath.addLine(to: CGPoint(x: 0, y: 12))
        arrowPath.close()
        let arrow = SKShapeNode(path: arrowPath.cgPath)
        arrow.fillColor = UIColor(hex: "#EF4444")
        arrow.strokeColor = .white
        arrow.lineWidth = 1
        node.addChild(arrow)

        return node
    }

    /// Striped tent/awning for the shop tab.
    func makeRushTabIcon() -> SKNode {
        let node = SKNode()
        let shadow = SKShapeNode(circleOfRadius: 14)
        shadow.fillColor = UIColor(white: 0, alpha: 0.16)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        node.addChild(shadow)

        let disc = SKShapeNode(circleOfRadius: 14)
        disc.fillColor = UIColor(hex: "#FB923C")
        disc.strokeColor = .white
        disc.lineWidth = 1.5
        node.addChild(disc)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 3, y: 9))
        path.addLine(to: CGPoint(x: -5, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -3, y: -9))
        path.addLine(to: CGPoint(x: 5, y: 1))
        path.addLine(to: CGPoint(x: 0, y: 1))
        path.close()
        let bolt = SKShapeNode(path: path.cgPath)
        bolt.fillColor = UIColor(hex: "#FEF08A")
        bolt.strokeColor = UIColor(hex: "#B45309")
        bolt.lineWidth = 1
        node.addChild(bolt)
        return node
    }

    func makeShopTabIcon() -> SKNode {
        let node = SKNode()

        // Drop shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: 36, height: 26),
                                  cornerRadius: 5)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        node.addChild(shadow)

        // Shop body (cream)
        let body = SKShapeNode(rectOf: CGSize(width: 34, height: 22),
                                 cornerRadius: 3)
        body.fillColor = UIColor(hex: "#FEF3C7")
        body.strokeColor = UIColor(hex: "#92400E")
        body.lineWidth = 1.5
        body.position = CGPoint(x: 0, y: -2)
        node.addChild(body)

        // Door
        let door = SKShapeNode(rectOf: CGSize(width: 8, height: 10),
                                cornerRadius: 2)
        door.fillColor = UIColor(hex: "#92400E")
        door.strokeColor = .clear
        door.position = CGPoint(x: 0, y: -7)
        node.addChild(door)

        // Awning — striped (red/white) with a scalloped bottom edge
        let awning = SKShapeNode(rectOf: CGSize(width: 38, height: 10),
                                  cornerRadius: 2)
        awning.fillColor = UIColor(hex: "#FECACA")
        awning.strokeColor = UIColor(hex: "#92400E")
        awning.lineWidth = 1.5
        awning.position = CGPoint(x: 0, y: 12)
        node.addChild(awning)

        for x: CGFloat in [-12, -4, 4, 12] {
            let stripe = SKShapeNode(rectOf: CGSize(width: 4, height: 10))
            stripe.fillColor = UIColor(hex: "#EF4444")
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: x, y: 12)
            node.addChild(stripe)
        }

        // Scallop bumps along the bottom of the awning (3 small circles)
        for x: CGFloat in [-12, 0, 12] {
            let bump = SKShapeNode(circleOfRadius: 2.5)
            bump.fillColor = UIColor(hex: "#FECACA")
            bump.strokeColor = UIColor(hex: "#92400E")
            bump.lineWidth = 1
            bump.position = CGPoint(x: x, y: 7)
            node.addChild(bump)
        }

        return node
    }

    func starShapePath(size: CGFloat) -> CGPath {
        let p = UIBezierPath()
        let outer = size / 2
        let inner = outer * 0.42
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / 5)
            let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        return p.cgPath
    }
}
