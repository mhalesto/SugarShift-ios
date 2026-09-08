import SpriteKit

// HUD: header, footer, helpers
extension GameScene {
    // MARK: - HUD: Header Card

    func rebuildHUD() {
        headerCard?.removeFromParent()
        footerCard?.removeFromParent()
        undoButton?.removeFromParent()
        comboMeterTrack?.parent?.removeFromParent()
        buildHeaderCard()
        buildFooterCard()
        buildUndoButton()
        buildComboMeter()
        updateHUD()
        updateComboMeter()
    }


    func addCrownToLevelLabelIfNeeded(_ label: SKLabelNode) {
        guard levelNumber >= 100 else { return }

        let crown = Icons.sprite(Icons.Name.crown,
                                 size: 13,
                                 weight: .heavy,
                                 tint: UIColor(hex: "#FACC15"))
        crown.name = "levelCrown"
        crown.position = CGPoint(x: 62, y: 22)
        crown.zPosition = 2
        label.addChild(crown)

        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = UIColor(hex: "#FACC15").withAlphaComponent(0.22)
        glow.strokeColor = .clear
        glow.position = crown.position
        glow.zPosition = 1
        label.addChild(glow)
    }

    /// Compact gold-edged marker. No circular backing or perpetual halo over
    /// the progress bar; only newly earned stars animate.
    func makeProgressStar(size: CGFloat) -> SKNode {
        let root = SKNode()
        let empty = GameplayHUDArt.star(size: size, earned: false)
        empty.name = "starEmpty"
        root.addChild(empty)
        let earned = GameplayHUDArt.star(size: size, earned: true)
        earned.name = "starEarned"
        earned.isHidden = true
        root.addChild(earned)
        return root
    }

    /// Builds a stack: glow halo → main gold star → subtle highlight → tiny sparkle layer.
    func makeShinyStar(size: CGFloat) -> SKNode {
        let container = SKNode()

        // Soft glow halo behind the star
        let halo = SKShapeNode(circleOfRadius: size * 0.78)
        halo.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.45)
        halo.strokeColor = .clear
        halo.glowWidth = 6
        halo.zPosition = -2
        halo.blendMode = .add
        container.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.18, duration: 1.6),
                    .fadeAlpha(to: 0.7, duration: 1.6)]),
            .group([.scale(to: 1.0, duration: 1.6),
                    .fadeAlpha(to: 0.4, duration: 1.6)])
        ])))

        // Main gold star
        let star = SKShapeNode(path: starPath(size: size))
        star.fillColor = UIColor(hex: "#FBBF24")        // warm gold
        star.strokeColor = UIColor(hex: "#B45309")     // amber edge
        star.lineWidth = 1
        star.glowWidth = 0.5
        star.zPosition = 0
        container.addChild(star)

        // Inner highlight — lighter gold, smaller, offset up-left for "lit from above" feel
        let highlight = SKShapeNode(path: starPath(size: size * 0.55))
        highlight.fillColor = UIColor(hex: "#FEF3C7").withAlphaComponent(0.85)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -size * 0.05, y: size * 0.06)
        highlight.zPosition = 1
        container.addChild(highlight)

        return container
    }

    /// 5-pointed star path centered at origin.
    func starPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let outer = size / 2
        let inner = outer * 0.42
        let points = 5
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / CGFloat(points))
            let p = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        return path.cgPath
    }

    /// Periodic sparkle: a tiny white dot grows + fades around the star.
    func scheduleSparkle(on node: SKNode, delay: TimeInterval) {
        let action = SKAction.run { [weak self, weak node] in
            guard let self = self, let node = node else { return }
            self.emitSparkle(on: node)
        }
        node.run(.sequence([
            .wait(forDuration: delay),
            .repeatForever(.sequence([
                action,
                .wait(forDuration: 2.0 + Double.random(in: 0...1.2))
            ]))
        ]))
    }

    func emitSparkle(on node: SKNode) {
        let r: CGFloat = 12
        let theta = CGFloat.random(in: 0...(.pi * 2))
        let dot = SKShapeNode(circleOfRadius: 1.6)
        dot.fillColor = .white
        dot.strokeColor = .clear
        dot.glowWidth = 3
        dot.blendMode = .add
        dot.position = CGPoint(x: r * cos(theta) * 0.6,
                               y: r * sin(theta) * 0.6)
        dot.zPosition = 3
        dot.alpha = 0
        dot.setScale(0.3)
        node.addChild(dot)

        dot.run(.sequence([
            .group([
                .scale(to: 1.8, duration: 0.18),
                .fadeAlpha(to: 1.0, duration: 0.1)
            ]),
            .group([
                .scale(to: 0.2, duration: 0.4),
                .fadeOut(withDuration: 0.4)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - HUD: Footer Card


    // MARK: - HUD helpers

    func makePill(width: CGFloat, height: CGFloat, fill: UIColor, stroke: UIColor) -> SKShapeNode {
        let pill = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        pill.fillColor = fill
        pill.strokeColor = stroke
        pill.lineWidth = stroke == .clear ? 0 : 1
        return pill
    }

    func makeSymbolCircle(symbol: String, diameter: CGFloat, fill: UIColor,
                                  iconTint: UIColor, iconSize: CGFloat,
                                  weight: UIImage.SymbolWeight = .bold) -> SKNode {
        let node = SKNode()
        let bg = SKShapeNode(circleOfRadius: diameter / 2)
        bg.fillColor = fill
        bg.strokeColor = .clear
        node.addChild(bg)
        let icon = Icons.sprite(symbol, size: iconSize, weight: weight, tint: iconTint)
        node.addChild(icon)
        return node
    }

    func updateHUD() {
        updatePremiumHUD()
        if worldNode != nil { worldEffects.synchronizeObjectives() }
    }


    /// Marks the header readouts as accessibility elements and gives each a
    /// spoken label that merges its caption with its current value.
    func applyHUDAccessibility() {
        movesValueLabel?.isAccessibilityElement = true
        movesValueLabel?.accessibilityLabel = String(localized: "Moves left: \(movesLeft)")

        goalLabel?.isAccessibilityElement = true
        goalLabel?.accessibilityLabel = String(localized: "Goal: \(goalProgressText())")

        starHintLabel?.isAccessibilityElement = true
        starHintLabel?.accessibilityLabel = nextStarText()

        livesLabel?.isAccessibilityElement = true
        livesLabel?.accessibilityLabel = String(localized: "Lives: \(lives) of \(livesMax)")

        totalLabel?.isAccessibilityElement = true
        totalLabel?.accessibilityLabel = String(localized: "Score: \(score). \(nextStarText())")

        cashLabel?.isAccessibilityElement = true
        cashLabel?.accessibilityLabel = String(localized: "Coins: \(cash)")

        comboMeterTrack?.isAccessibilityElement = true
        let bossStatus = levelConfig.isBoss
            ? String(localized: ", crown shield \(bossShieldRemaining) of \(bossShieldMaximum)")
            : ""
        let flowStatus = flowLevel > 0
            ? String(localized: ", Flow \(flowLevel) of \(TurnMasteryPolicy.maximumFlow)")
            : ""
        let rushStatus = sugarRushCharged ? ", " + String(localized: "SUGAR RUSH READY") : ""
        let targetingStatus: String
        if smashTargeting, let tier = selectedSmashTier {
            let instruction = smashPreviewTarget == nil
                ? String(localized: "TAP A TILE")
                : String(localized: "TAP AGAIN TO SMASH")
            targetingStatus = ", " + tier.title + " " + instruction
        } else {
            targetingStatus = ""
        }
        comboMeterTrack?.accessibilityLabel = String(localized: "Smash charge \(smashCharge) percent\(bossStatus)")
            + flowStatus + rushStatus + targetingStatus
    }

    func goalProgressText() -> String {
        objectiveTracker.progresses.map { "\($0.objective.accessibilityTitle) \($0.current)/\($0.target)" }.joined(separator: " • ")
    }

    func nextStarText() -> String {
        LevelScoring.nextStarText(for: levelConfig,
                                  performance: currentPerformance(),
                                  objectiveComplete: isLevelGoalComplete)
    }

    func currentPerformance(effectiveMovesLeft: Int? = nil) -> LevelAttemptPerformance {
        LevelAttemptPerformance(score: score,
                                movesLeft: effectiveMovesLeft ?? max(0, movesLeft),
                                movesAtStart: movesAtStart,
                                maxCascadeDepth: maxCascadeDepth,
                                createdSpecials: createdSpecials,
                                detonatedBombs: detonatedBombs,
                                objectiveProgress: currentObjectiveProgress())
    }

    func currentObjectiveProgress() -> Double {
        objectiveTracker.progressFraction
    }
}
