import SpriteKit

// Sky, level positions, background decorations
extension LevelMapScene {
    // MARK: - Sky background (fixed)

    func buildSky() {
        // The view-controller already paints a pastel pink/lavender gradient. We add a
        // soft top stripe band (diagonal candy stripes, like Candy Crush) for extra polish.
        stripe = SKNode()
        stripe.zPosition = -10
        addChild(stripe)

        // Top stripe band: diagonal soft pink/cream stripes on a pink base.
        let bandHeight: CGFloat = 80
        let bandY = size.height / 2 - bandHeight / 2
        let band = SKShapeNode(rectOf: CGSize(width: size.width, height: bandHeight))
        band.fillColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.55)
        band.strokeColor = .clear
        band.position = CGPoint(x: 0, y: bandY)
        band.zPosition = -10
        stripe.addChild(band)

        // Diagonal stripes drawn on top
        for i in 0..<24 {
            let off = CGFloat(i) * 28 - size.width / 2 - 80
            let s = SKShapeNode(rectOf: CGSize(width: 14, height: bandHeight * 1.6))
            s.fillColor = UIColor.white.withAlphaComponent(0.30)
            s.strokeColor = .clear
            s.zRotation = .pi / 8
            s.position = CGPoint(x: off, y: bandY)
            stripe.addChild(s)
        }
    }

    // MARK: - Level positions on the winding path

    func computeLevelPositions() {
        var y: CGFloat = 0
        for n in 1...levelCount {
            if n > 1 {
                // After each group of `levelsPerGroup`, insert a vista gap.
                let didJustFinishGroup = ((n - 1) % levelsPerGroup == 0) && (n - 1) < levelCount
                y += didJustFinishGroup ? (levelStep + vistaHeight) : levelStep
            }
            let phase = CGFloat(n) * 0.78
            let x = sin(phase) * swingWidth
            levelPositions[n] = CGPoint(x: x, y: y)
        }
    }

    func computeScrollBounds() {
        let H = size.height
        let topInset: CGFloat    = hudTopMargin + 146
        let bottomInset: CGFloat = bottomChromeMargin + bottomBarHeight + 138

        guard let last = levelPositions[levelCount],
              let first = levelPositions[1] else { return }

        // Most negative — keeps the highest level just below the HUD.
        worldYMin = (H / 2 - topInset) - last.y
        // Most positive — keeps the lowest level just above the bottom bar.
        worldYMax = (-H / 2 + bottomInset) - first.y

        // Guard against tiny content; the generated route should always exceed the viewport.
        if worldYMin > worldYMax { worldYMin = worldYMax }
    }

    func scrollToLevel(_ n: Int, animated: Bool) {
        guard let p = levelPositions[max(1, min(n, levelCount))] else { return }
        // Center the requested level vertically on screen.
        let targetY = clampedWorldY(-p.y + size.height * 0.05)  // bias slightly above center
        if animated {
            world.run(.move(to: CGPoint(x: 0, y: targetY), duration: 0.6))
        } else {
            world.position = CGPoint(x: 0, y: targetY)
        }
    }

    func clampedWorldY(_ y: CGFloat) -> CGFloat {
        max(worldYMin, min(worldYMax, y))
    }

    // MARK: - Background decorations (parallax)

    func buildBackgroundDecorations() {
        // Sprinkle tree puffs, lamp posts, daisies, clouds along the world.
        // bgFar moves slowest, bgMid medium, world (level/path) fastest.
        let palette: [UIColor] = [
            UIColor(hex: "#F9A8D4"),   // pink
            UIColor(hex: "#DDD6FE"),   // lavender
            UIColor(hex: "#A7F3D0"),   // mint
            UIColor(hex: "#FED7AA")    // peach
        ]

        let halfW = size.width / 2

        for n in 1...levelCount {
            guard let p = levelPositions[n] else { continue }

            // 2 trees per level slot (one each side, randomised)
            for side: CGFloat in [-1, 1] {
                let baseX = side * (halfW * CGFloat.random(in: 0.55...0.95))
                let yOff = CGFloat.random(in: -50...50)
                let tree = makeTree(color: palette.randomElement()!,
                                    radius: CGFloat.random(in: 28...54))
                tree.position = CGPoint(x: baseX, y: p.y + yOff)
                tree.zPosition = -1
                bgFar.addChild(tree)
            }

            // Daisies on the ground
            if n % 2 == 0 {
                for _ in 0..<3 {
                    let daisy = makeDaisy()
                    daisy.position = CGPoint(
                        x: CGFloat.random(in: -halfW + 20 ... halfW - 20),
                        y: p.y + CGFloat.random(in: -90...90))
                    daisy.zPosition = 1
                    bgMid.addChild(daisy)
                }
            }

            // Lamp posts every few levels
            if n % 3 == 0 {
                let lamp = makeLampPost()
                let dir: CGFloat = (n % 2 == 0) ? 1 : -1
                lamp.position = CGPoint(x: dir * (halfW * 0.7),
                                        y: p.y + CGFloat.random(in: -40...40))
                lamp.zPosition = 2
                bgMid.addChild(lamp)
            }
        }

        // Clouds at the very top of the map
        if let topLevel = levelPositions[levelCount] {
            for _ in 0..<5 {
                let cloud = makeCloud()
                cloud.position = CGPoint(
                    x: CGFloat.random(in: -halfW...halfW),
                    y: topLevel.y + CGFloat.random(in: 60...260))
                cloud.zPosition = -2
                bgFar.addChild(cloud)
                let dur1 = TimeInterval.random(in: 6...9)
                let dur2 = TimeInterval.random(in: 6...9)
                cloud.run(.repeatForever(.sequence([
                    .moveBy(x: 30, y: 0, duration: dur1),
                    .moveBy(x: -30, y: 0, duration: dur2)
                ])))
            }
        }
    }
}
