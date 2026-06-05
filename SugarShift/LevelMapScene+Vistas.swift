import SpriteKit

// Vista scenes
extension LevelMapScene {
    // MARK: - Vista scenes (the "skip 10 levels and show something nice" moments)

    func buildVistaScenes() {
        // A vista appears after each group: between level groupEnd and groupEnd+1.
        // Centered halfway between those two level Ys.
        var groupEnd = levelsPerGroup
        var vistaIndex = 0
        while groupEnd < levelCount {
            guard let pa = levelPositions[groupEnd],
                  let pb = levelPositions[groupEnd + 1] else { break }
            let centerY = (pa.y + pb.y) / 2
            let style = VistaStyle.allCases[vistaIndex % VistaStyle.allCases.count]
            let vista = makeVistaScene(style: style)
            vista.position = CGPoint(x: 0, y: centerY)
            vista.zPosition = 3
            world.addChild(vista)
            groupEnd += levelsPerGroup
            vistaIndex += 1
        }
    }

    enum VistaStyle: CaseIterable {
        case river, candyGarden, lollipopGrove, railwayCrossing, balloons
    }

    func makeVistaScene(style: VistaStyle) -> SKNode {
        let node = SKNode()
        switch style {
        case .river:           buildRiverVista(into: node)
        case .candyGarden:     buildCandyGardenVista(into: node)
        case .lollipopGrove:   buildLollipopGroveVista(into: node)
        case .railwayCrossing: buildRailwayCrossingVista(into: node)
        case .balloons:        buildBalloonsVista(into: node)
        }
        return node
    }

    /// Animated water river crossing the full width.
    func buildRiverVista(into node: SKNode) {
        let width = size.width * 1.1
        let height: CGFloat = 150

        // Stone shore strip (top)
        let topShore = SKShapeNode(rectOf: CGSize(width: width, height: 24),
                                    cornerRadius: 12)
        topShore.fillColor = UIColor(hex: "#FCD9C8")
        topShore.strokeColor = .clear
        topShore.position = CGPoint(x: 0, y: height / 2 + 12)
        node.addChild(topShore)

        // Water body
        let water = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                 cornerRadius: 22)
        water.fillColor = UIColor(hex: "#A78BFA")    // soft purple
        water.strokeColor = UIColor(hex: "#8B5CF6").withAlphaComponent(0.4)
        water.lineWidth = 2
        water.position = .zero
        node.addChild(water)

        // Water gradient overlay (lighter at top)
        let gradOverlay = SKShapeNode(rectOf: CGSize(width: width, height: height / 2),
                                      cornerRadius: 18)
        gradOverlay.fillColor = UIColor(hex: "#C4B5FD").withAlphaComponent(0.5)
        gradOverlay.strokeColor = .clear
        gradOverlay.position = CGPoint(x: 0, y: height / 4)
        node.addChild(gradOverlay)

        waterRivers.append((water, 0))

        // Drifting wave layers (sine ribbons that loop sideways).
        for layer in 0..<3 {
            let wave = makeWaveRibbon(width: width * 1.6,
                                      amplitude: 4 + CGFloat(layer),
                                      wavelength: 60 - CGFloat(layer) * 8,
                                      thickness: 2,
                                      color: UIColor.white.withAlphaComponent(0.55 - CGFloat(layer) * 0.12))
            let yOff = CGFloat(layer) * 22 - 14
            wave.position = CGPoint(x: 0, y: yOff)
            wave.zPosition = 1
            node.addChild(wave)

            let dir: CGFloat = (layer % 2 == 0) ? 1 : -1
            let speed: CGFloat = 24 + CGFloat(layer) * 6
            waveLayers.append((wave, speed * dir, 0, width))
        }

        // Foam bubbles drifting along the surface
        for _ in 0..<10 {
            let foam = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            foam.fillColor = .white
            foam.strokeColor = .clear
            foam.alpha = 0.7
            foam.position = CGPoint(
                x: CGFloat.random(in: -width / 2...width / 2),
                y: CGFloat.random(in: -height / 2 + 8...height / 2 - 8))
            node.addChild(foam)
            let drift = TimeInterval.random(in: 6...11)
            foam.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: 80...160), y: 0, duration: drift),
                    .sequence([.fadeAlpha(to: 0.95, duration: drift / 2),
                               .fadeAlpha(to: 0.5,  duration: drift / 2)])
                ]),
                .moveBy(x: -200, y: 0, duration: 0.01)
            ])))
        }

        // Periodic ripple emitter
        let ripple = SKAction.run { [weak self] in self?.spawnRipple(in: node, width: width, height: height) }
        node.run(.repeatForever(.sequence([ripple, .wait(forDuration: 0.65, withRange: 0.6)])))

        // Stones poking out of the water
        for i in 0..<3 {
            let stone = makeStone(width: 36 + CGFloat(i) * 8, height: 14)
            stone.position = CGPoint(x: CGFloat.random(in: -width / 2 + 60 ... width / 2 - 60),
                                     y: CGFloat.random(in: -height / 2 + 18 ... height / 2 - 26))
            node.addChild(stone)
        }

        // Bottom shore
        let botShore = SKShapeNode(rectOf: CGSize(width: width, height: 24),
                                    cornerRadius: 12)
        botShore.fillColor = UIColor(hex: "#A7F3D0").withAlphaComponent(0.85)
        botShore.strokeColor = .clear
        botShore.position = CGPoint(x: 0, y: -height / 2 - 12)
        node.addChild(botShore)

        // Wooden bridge over the river — sits on top of the path
        let bridge = makeBridge(width: 90, height: height + 40)
        bridge.position = .zero
        bridge.zPosition = 5
        node.addChild(bridge)
    }

    /// Cute candy garden tableau — lollipop trees, swirl candies, gumballs.
    func buildCandyGardenVista(into node: SKNode) {
        // Soft dirt patch
        let patch = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.85, height: 180))
        patch.fillColor = UIColor(hex: "#FBE5C8")
        patch.strokeColor = .clear
        patch.zPosition = -1
        node.addChild(patch)

        // Two lollipop trees (one each side)
        for side: CGFloat in [-1, 1] {
            let tree = makeLollipopTree(side: side)
            tree.position = CGPoint(x: side * size.width * 0.30, y: 30)
            node.addChild(tree)
        }

        // Swirl candies scattered
        for _ in 0..<6 {
            let swirl = makeSwirlCandy(radius: CGFloat.random(in: 8...14))
            swirl.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 30 ... size.width / 2 - 30),
                y: CGFloat.random(in: -50...50))
            node.addChild(swirl)
            swirl.run(.repeatForever(.sequence([
                .rotate(byAngle: .pi * 2, duration: TimeInterval.random(in: 6...10))
            ])))
        }

        // Gumball bushes
        for side: CGFloat in [-1, 1] {
            let bush = makeGumballBush()
            bush.position = CGPoint(x: side * size.width * 0.42, y: -50)
            node.addChild(bush)
        }
    }

    /// Pink-puff lollipop grove with candy floss bushes.
    func buildLollipopGroveVista(into node: SKNode) {
        // A pink hilltop dome
        let hill = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.0, height: 200))
        hill.fillColor = UIColor(hex: "#FCE7F3")
        hill.strokeColor = .clear
        hill.zPosition = -1
        node.addChild(hill)

        // 3 lollipop trees of different colors
        let lollyColors = [UIColor(hex: "#F472B6"),
                           UIColor(hex: "#A78BFA"),
                           UIColor(hex: "#FBBF24")]
        for (i, color) in lollyColors.enumerated() {
            let pos = CGPoint(x: CGFloat(i - 1) * 110, y: 30)
            let tree = makeLollipopTree(side: i.isMultiple(of: 2) ? -1 : 1, color: color)
            tree.position = pos
            tree.setScale(CGFloat.random(in: 0.85...1.05))
            node.addChild(tree)
        }

        // Candy-floss puff trees around the edges
        for side: CGFloat in [-1, 1] {
            let puff = makeFloss()
            puff.position = CGPoint(x: side * size.width * 0.45, y: 0)
            node.addChild(puff)
        }

        // Floating sparkles
        for _ in 0..<8 {
            let spark = SKLabelNode(text: "✦")
            spark.fontName = "AvenirNext-Heavy"
            spark.fontSize = CGFloat.random(in: 12...18)
            spark.fontColor = UIColor(hex: "#FFFBEB")
            spark.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2...size.width / 2),
                y: CGFloat.random(in: -100...100))
            spark.alpha = 0.0
            node.addChild(spark)
            spark.run(.repeatForever(.sequence([
                .wait(forDuration: TimeInterval.random(in: 0...3)),
                .fadeAlpha(to: 1.0, duration: 0.6),
                .scale(to: 1.3, duration: 0.6),
                .group([.fadeAlpha(to: 0.0, duration: 0.6),
                        .scale(to: 0.6, duration: 0.6)])
            ])))
        }
    }

    /// Animated railway crossing — striped gates that rise/lower, train chugs
    /// across with smoke puffs and spinning wheels, conductor character watches.
    func buildRailwayCrossingVista(into node: SKNode) {
        let width = size.width * 1.0

        // Sand mound the tracks rest on
        let mound = SKShapeNode(rectOf: CGSize(width: width * 1.5, height: 110),
                                  cornerRadius: 30)
        mound.fillColor = UIColor(hex: "#FBE5C8")
        mound.strokeColor = .clear
        mound.zPosition = -2
        node.addChild(mound)

        // Track ties (sit *under* the rails)
        let tieY: CGFloat = 0
        for x in stride(from: -width / 2, through: width / 2, by: 28) {
            let tie = SKShapeNode(rectOf: CGSize(width: 18, height: 6),
                                    cornerRadius: 1.5)
            tie.fillColor = UIColor(hex: "#A06A4A")
            tie.strokeColor = UIColor(hex: "#7B4E33").withAlphaComponent(0.7)
            tie.lineWidth = 0.5
            tie.position = CGPoint(x: x, y: tieY)
            tie.zPosition = -1
            node.addChild(tie)
        }

        // Two parallel rails
        for offset: CGFloat in [-7, 7] {
            let rail = SKShapeNode(rectOf: CGSize(width: width, height: 3),
                                     cornerRadius: 1.5)
            rail.fillColor = UIColor(hex: "#7DD3FC")
            rail.strokeColor = UIColor(hex: "#0284C7").withAlphaComponent(0.5)
            rail.lineWidth = 0.5
            rail.position = CGPoint(x: 0, y: tieY + offset)
            rail.zPosition = 0
            node.addChild(rail)
        }

        // Crossing gates on each side of the track
        for side: CGFloat in [-1, 1] {
            let hinge = SKNode()
            hinge.position = CGPoint(x: side * (width * 0.34), y: 14)
            hinge.zPosition = 7
            node.addChild(hinge)

            // Yellow vertical post
            let post = SKShapeNode(rectOf: CGSize(width: 8, height: 56),
                                     cornerRadius: 2)
            post.fillColor = UIColor(hex: "#FACC15")
            post.strokeColor = UIColor(hex: "#92400E")
            post.lineWidth = 1
            post.position = CGPoint(x: 0, y: -16)
            hinge.addChild(post)

            // Striped boom arm — pivots around the hinge
            let arm = makeRailwayArm(direction: -side)
            arm.zRotation = 0
            hinge.addChild(arm)

            let openAngle: CGFloat = -side * .pi / 2
            arm.run(.repeatForever(.sequence([
                .wait(forDuration: 1.1),
                .rotate(toAngle: openAngle, duration: 0.55),
                .wait(forDuration: 4.2),
                .rotate(toAngle: 0,         duration: 0.55),
                .wait(forDuration: 1.0)
            ])))
        }

        // Train chugging across — synchronised so it crosses while gates are up
        let train = makeTrain()
        train.position = CGPoint(x: -width / 2 - 110, y: 22)
        train.zPosition = 6
        node.addChild(train)
        train.run(.repeatForever(.sequence([
            .wait(forDuration: 1.7),
            .moveTo(x: width / 2 + 110, duration: 4.0),
            .moveTo(x: -width / 2 - 110, duration: 0.01),
            .wait(forDuration: 1.6)
        ])))

        // Conductor character on the right shoulder of the track
        let conductor = makeConductor()
        conductor.position = CGPoint(x: width * 0.18, y: -38)
        conductor.zPosition = 8
        node.addChild(conductor)

        // A few flying confetti dots so the scene feels alive when train passes
        for _ in 0..<6 {
            let bit = SKShapeNode(rectOf: CGSize(width: 5, height: 8))
            bit.fillColor = [UIColor(hex: "#F472B6"), UIColor(hex: "#FBBF24"),
                              UIColor(hex: "#34D399"), UIColor(hex: "#A78BFA")].randomElement()!
            bit.strokeColor = .clear
            bit.position = CGPoint(x: CGFloat.random(in: -width / 2 ... width / 2),
                                     y: CGFloat.random(in: 60...140))
            bit.zRotation = CGFloat.random(in: 0...(.pi * 2))
            bit.zPosition = 5
            node.addChild(bit)
            bit.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: -100, duration: 4),
                .moveBy(x: 0, y: 100, duration: 0.01)
            ])))
        }
    }

    /// Striped boom arm that pivots up/down at a railway gate.
    func makeRailwayArm(direction: CGFloat) -> SKNode {
        let arm = SKNode()
        let length: CGFloat = 92
        let thickness: CGFloat = 12

        let body = SKShapeNode(rectOf: CGSize(width: length, height: thickness),
                                 cornerRadius: 3)
        body.fillColor = .white
        body.strokeColor = UIColor(hex: "#92400E")
        body.lineWidth = 1.2
        body.position = CGPoint(x: direction * (length / 2), y: 14)
        arm.addChild(body)

        for i in 0..<5 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 9, height: thickness),
                                       cornerRadius: 1)
            stripe.fillColor = UIColor(hex: "#EF4444")
            stripe.strokeColor = .clear
            let xOff = direction * (10 + CGFloat(i) * 18)
            stripe.position = CGPoint(x: xOff, y: 14)
            arm.addChild(stripe)
        }

        let cap = SKShapeNode(circleOfRadius: 5)
        cap.fillColor = UIColor(hex: "#FACC15")
        cap.strokeColor = UIColor(hex: "#92400E")
        cap.lineWidth = 1
        cap.position = CGPoint(x: 0, y: 14)
        arm.addChild(cap)
        return arm
    }

    /// Cute boxy train: engine + cargo car + spinning wheels + smoke puffs.
    func makeTrain() -> SKNode {
        let node = SKNode()

        let cargoBody = SKShapeNode(rectOf: CGSize(width: 38, height: 24),
                                      cornerRadius: 4)
        cargoBody.fillColor = UIColor(hex: "#F472B6")
        cargoBody.strokeColor = UIColor(hex: "#BE185D")
        cargoBody.lineWidth = 1.5
        cargoBody.position = CGPoint(x: -52, y: 4)
        node.addChild(cargoBody)

        let load = SKShapeNode(rectOf: CGSize(width: 30, height: 8),
                                cornerRadius: 4)
        load.fillColor = UIColor(hex: "#FBBF24")
        load.strokeColor = UIColor(hex: "#92400E")
        load.lineWidth = 1
        load.position = CGPoint(x: -52, y: 18)
        node.addChild(load)

        let coupling = SKShapeNode(rectOf: CGSize(width: 6, height: 2))
        coupling.fillColor = UIColor(hex: "#374151")
        coupling.strokeColor = .clear
        coupling.position = CGPoint(x: -30, y: -8)
        node.addChild(coupling)

        let body = SKShapeNode(rectOf: CGSize(width: 50, height: 28),
                                 cornerRadius: 6)
        body.fillColor = UIColor(hex: "#3B82F6")
        body.strokeColor = UIColor(hex: "#1E40AF")
        body.lineWidth = 1.5
        body.position = CGPoint(x: 0, y: 4)
        node.addChild(body)

        let cab = SKShapeNode(rectOf: CGSize(width: 22, height: 14),
                                cornerRadius: 3)
        cab.fillColor = UIColor(hex: "#EF4444")
        cab.strokeColor = UIColor(hex: "#7F1D1D")
        cab.lineWidth = 1.2
        cab.position = CGPoint(x: -10, y: 22)
        node.addChild(cab)

        let window = SKShapeNode(rectOf: CGSize(width: 8, height: 7),
                                   cornerRadius: 1)
        window.fillColor = UIColor(hex: "#7DD3FC")
        window.strokeColor = UIColor.white.withAlphaComponent(0.6)
        window.lineWidth = 0.6
        window.position = CGPoint(x: -10, y: 22)
        node.addChild(window)

        let stack = SKShapeNode(rectOf: CGSize(width: 6, height: 12),
                                  cornerRadius: 2)
        stack.fillColor = UIColor(hex: "#1E40AF")
        stack.strokeColor = UIColor(hex: "#0F172A").withAlphaComponent(0.4)
        stack.lineWidth = 0.5
        stack.position = CGPoint(x: 16, y: 24)
        node.addChild(stack)

        let headlight = SKShapeNode(circleOfRadius: 3)
        headlight.fillColor = UIColor(hex: "#FACC15")
        headlight.strokeColor = .white
        headlight.lineWidth = 0.6
        headlight.position = CGPoint(x: 24, y: 4)
        node.addChild(headlight)

        let wheelXs: [CGFloat] = [-16, 16, -42, -62]
        for x in wheelXs {
            let wheel = SKShapeNode(circleOfRadius: 5.5)
            wheel.fillColor = UIColor(hex: "#374151")
            wheel.strokeColor = UIColor(hex: "#FACC15")
            wheel.lineWidth = 1.5
            wheel.position = CGPoint(x: x, y: -10)
            node.addChild(wheel)

            let spoke = SKShapeNode(rectOf: CGSize(width: 1, height: 7))
            spoke.fillColor = UIColor(hex: "#FACC15")
            spoke.strokeColor = .clear
            wheel.addChild(spoke)

            wheel.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.55)))
        }

        for delay in [0.0, 0.55, 1.1] {
            let puff = SKShapeNode(circleOfRadius: 4)
            puff.fillColor = UIColor.white.withAlphaComponent(0.85)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: 16, y: 32)
            puff.alpha = 0
            node.addChild(puff)

            puff.run(.repeatForever(.sequence([
                .wait(forDuration: delay),
                .group([
                    .moveBy(x: 16, y: 38, duration: 1.4),
                    .scale(to: 2.2, duration: 1.4),
                    .sequence([.fadeAlpha(to: 0.9, duration: 0.2),
                               .fadeOut(withDuration: 1.2)])
                ]),
                .group([
                    .moveBy(x: -16, y: -38, duration: 0.01),
                    .scale(to: 1.0, duration: 0.01)
                ])
            ])))
        }
        return node
    }

    /// Conductor character — friendly waving figure with a striped cap.
    func makeConductor() -> SKNode {
        let node = SKNode()

        for x: CGFloat in [-5, 5] {
            let shoe = SKShapeNode(rectOf: CGSize(width: 8, height: 4),
                                     cornerRadius: 2)
            shoe.fillColor = UIColor(hex: "#0F172A")
            shoe.strokeColor = .clear
            shoe.position = CGPoint(x: x, y: -32)
            node.addChild(shoe)
        }

        let pants = SKShapeNode(rectOf: CGSize(width: 14, height: 18),
                                  cornerRadius: 3)
        pants.fillColor = UIColor(hex: "#3B82F6")
        pants.strokeColor = UIColor(hex: "#1E40AF")
        pants.lineWidth = 1
        pants.position = CGPoint(x: 0, y: -22)
        node.addChild(pants)

        let shirt = SKShapeNode(rectOf: CGSize(width: 18, height: 18),
                                  cornerRadius: 4)
        shirt.fillColor = UIColor(hex: "#7DD3FC")
        shirt.strokeColor = UIColor(hex: "#0284C7")
        shirt.lineWidth = 1
        shirt.position = CGPoint(x: 0, y: -6)
        node.addChild(shirt)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = UIColor(hex: "#A06A4A")
        head.strokeColor = UIColor(hex: "#7B4E33")
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 12)
        node.addChild(head)

        for x: CGFloat in [-2.5, 2.5] {
            let eye = SKShapeNode(circleOfRadius: 1.1)
            eye.fillColor = UIColor(hex: "#0F172A")
            eye.strokeColor = .clear
            eye.position = CGPoint(x: x, y: 13)
            node.addChild(eye)
        }
        let smilePath = UIBezierPath()
        smilePath.move(to: CGPoint(x: -2, y: 10))
        smilePath.addQuadCurve(to: CGPoint(x: 2, y: 10),
                                controlPoint: CGPoint(x: 0, y: 8))
        let smile = SKShapeNode(path: smilePath.cgPath)
        smile.strokeColor = UIColor(hex: "#0F172A")
        smile.lineWidth = 1
        smile.lineCap = .round
        smile.fillColor = .clear
        node.addChild(smile)

        // Striped cap (white stripes + blue body)
        let capBase = SKShapeNode(rectOf: CGSize(width: 16, height: 6),
                                    cornerRadius: 1)
        capBase.fillColor = .white
        capBase.strokeColor = UIColor(hex: "#0284C7")
        capBase.lineWidth = 0.8
        capBase.position = CGPoint(x: 0, y: 22)
        node.addChild(capBase)
        for i in 0..<3 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 3, height: 6))
            stripe.fillColor = UIColor(hex: "#3B82F6")
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: -6 + CGFloat(i) * 6, y: 22)
            node.addChild(stripe)
        }
        let capTop = SKShapeNode(rectOf: CGSize(width: 14, height: 6),
                                   cornerRadius: 3)
        capTop.fillColor = UIColor(hex: "#3B82F6")
        capTop.strokeColor = UIColor(hex: "#1E40AF")
        capTop.lineWidth = 0.8
        capTop.position = CGPoint(x: 0, y: 26)
        node.addChild(capTop)

        // Waving arm with lantern
        let arm = SKNode()
        arm.position = CGPoint(x: 8, y: 0)
        node.addChild(arm)

        let armLine = SKShapeNode(rectOf: CGSize(width: 4, height: 14),
                                    cornerRadius: 2)
        armLine.fillColor = UIColor(hex: "#7DD3FC")
        armLine.strokeColor = UIColor(hex: "#0284C7")
        armLine.lineWidth = 0.8
        armLine.position = CGPoint(x: 4, y: -2)
        armLine.zRotation = -.pi / 4
        arm.addChild(armLine)

        let lantern = SKShapeNode(circleOfRadius: 3)
        lantern.fillColor = UIColor(hex: "#FACC15")
        lantern.strokeColor = UIColor(hex: "#92400E")
        lantern.lineWidth = 0.8
        lantern.glowWidth = 4
        lantern.position = CGPoint(x: 12, y: 6)
        arm.addChild(lantern)

        node.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1, duration: 1.2),
            .moveBy(x: 0, y: -1, duration: 1.2)
        ])))
        arm.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.18, duration: 0.6),
            .rotate(byAngle: -0.36, duration: 1.2),
            .rotate(byAngle: 0.18, duration: 0.6)
        ])))
        return node
    }

    /// Hot-air balloons drifting upward and bobbing.
    func buildBalloonsVista(into node: SKNode) {
        let field = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.95,
                                                    height: 140))
        field.fillColor = UIColor(hex: "#FCD9C8")
        field.strokeColor = .clear
        field.position = CGPoint(x: 0, y: -50)
        field.zPosition = -1
        node.addChild(field)

        let palette: [UIColor] = [
            UIColor(hex: "#F472B6"),
            UIColor(hex: "#FBBF24"),
            UIColor(hex: "#A78BFA"),
            UIColor(hex: "#34D399")
        ]

        for (i, color) in palette.enumerated() {
            let balloon = makeBalloon(color: color)
            let xPos = CGFloat(i - 2) * 78 + 40 + CGFloat.random(in: -8...8)
            balloon.position = CGPoint(x: xPos,
                                         y: CGFloat.random(in: -10...30))
            balloon.zPosition = 5
            node.addChild(balloon)

            let bobAmt: CGFloat = 12 + CGFloat(i) * 2
            let dur = TimeInterval.random(in: 1.6...2.4)
            balloon.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: bobAmt, duration: dur),
                .moveBy(x: 0, y: -bobAmt, duration: dur)
            ])))
            balloon.run(.repeatForever(.sequence([
                .rotate(byAngle: 0.05, duration: 1.4),
                .rotate(byAngle: -0.10, duration: 2.4),
                .rotate(byAngle: 0.05, duration: 1.4)
            ])))
        }

        for _ in 0..<3 {
            let cloud = makeCloud()
            cloud.alpha = 0.85
            cloud.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2...size.width / 2),
                y: CGFloat.random(in: 50...110))
            cloud.zPosition = 2
            node.addChild(cloud)
            let dist: CGFloat = 30
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: dist, y: 0, duration: 8),
                .moveBy(x: -dist, y: 0, duration: 8)
            ])))
        }
    }

    /// One hot-air balloon with stripe + basket + string.
    func makeBalloon(color: UIColor) -> SKNode {
        let node = SKNode()

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 28, height: 6))
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -56)
        node.addChild(shadow)

        let body = SKShapeNode(ellipseOf: CGSize(width: 42, height: 50))
        body.fillColor = color
        body.strokeColor = UIColor(white: 0, alpha: 0.22)
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: 8)
        node.addChild(body)

        let stripe = SKShapeNode(ellipseOf: CGSize(width: 8, height: 50))
        stripe.fillColor = UIColor.white.withAlphaComponent(0.6)
        stripe.strokeColor = .clear
        stripe.position = CGPoint(x: 0, y: 8)
        node.addChild(stripe)

        let hi = SKShapeNode(ellipseOf: CGSize(width: 12, height: 16))
        hi.fillColor = UIColor.white.withAlphaComponent(0.6)
        hi.strokeColor = .clear
        hi.position = CGPoint(x: -10, y: 18)
        node.addChild(hi)

        let knot = SKShapeNode(rectOf: CGSize(width: 6, height: 4),
                                 cornerRadius: 1)
        knot.fillColor = color
        knot.strokeColor = .clear
        knot.position = CGPoint(x: 0, y: -20)
        node.addChild(knot)

        let stringPath = UIBezierPath()
        stringPath.move(to: CGPoint(x: 0, y: -22))
        stringPath.addQuadCurve(to: CGPoint(x: 4, y: -46),
                                  controlPoint: CGPoint(x: -3, y: -34))
        let str = SKShapeNode(path: stringPath.cgPath)
        str.strokeColor = UIColor(white: 0.3, alpha: 0.6)
        str.lineWidth = 1
        str.fillColor = .clear
        node.addChild(str)

        let basket = SKShapeNode(rectOf: CGSize(width: 18, height: 12),
                                   cornerRadius: 2)
        basket.fillColor = UIColor(hex: "#A06A4A")
        basket.strokeColor = UIColor(hex: "#7B4E33")
        basket.lineWidth = 1
        basket.position = CGPoint(x: 4, y: -50)
        node.addChild(basket)

        for x: CGFloat in [-4, 0, 4] {
            let line = SKShapeNode(rectOf: CGSize(width: 0.8, height: 10))
            line.fillColor = UIColor(hex: "#7B4E33").withAlphaComponent(0.65)
            line.strokeColor = .clear
            line.position = CGPoint(x: 4 + x, y: -50)
            node.addChild(line)
        }
        return node
    }
}
