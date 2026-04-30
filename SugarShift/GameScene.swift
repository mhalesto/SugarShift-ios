import SpriteKit

final class GameScene: SKScene {

    // MARK: - Config (driven by Levels catalog)

    private var levelConfig: LevelConfig = Levels.config(for: 1)
    private var rows: Int { levelConfig.rows }
    private var cols: Int { levelConfig.cols }
    private var palette: [String] { Array(Theme.colors.prefix(levelConfig.colors)) }
    private var skin: BoardSkin { levelConfig.skin }

    private var levelNumber: Int { levelConfig.number }
    private var movesAtStart: Int { levelConfig.moves }
    private var scoreTarget: Int { levelConfig.target }

    // Placeholder economy state (UI only, not wired to gameplay)
    private var lives = 5
    private let livesMax = 6
    private var totalScore = 34030
    private var cash = 2553

    private var endLevelCard: EndLevelCard?
    private var levelEnded = false

    // MARK: - Game state

    private var grid: Grid = []
    private var nodes: [[SKNode?]] = []
    private var tileSize: CGFloat = 0
    private var gap: CGFloat = 0
    private var boardOrigin: CGPoint = .zero
    private var safeTop: CGFloat = 0
    private var safeBottom: CGFloat = 0

    private var firstSelection: Pos?
    private var firstSelectionNode: SKNode?
    private var dragStartPoint: CGPoint?
    private var isResolving = false
    private var cascadeDepth = 0

    // +Moves booster: quantity selector state
    private let quantityOptions: [Int] = [1, 5, 10, 25, 50]
    private var movesQuantity: Int = 5
    private let movesBuyCost: Int = 119
    private weak var movesBoosterCircle: SKShapeNode?
    private weak var movesQuantityBadge: SKShapeNode?
    private weak var movesQuantityBadgeLabel: SKLabelNode?
    private var quantityPopup: SKNode?

    private var score: Int = 0 { didSet { updateHUD() } }
    private var movesLeft: Int = 0 { didSet { updateHUD() } }

    // Container for shake (we move this instead of self.position)
    private var worldNode: SKNode!

    // HUD nodes
    private var headerCard: SKShapeNode!
    private var footerCard: SKShapeNode!
    private var livesLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!
    private var goalLabel: SKLabelNode!
    private var totalLabel: SKLabelNode!
    private var movesValueLabel: SKLabelNode!
    private var progressFill: SKShapeNode!
    private var progressTrack: SKShapeNode!
    private var cashLabel: SKLabelNode!

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        safeTop = view.safeAreaInsets.top
        safeBottom = view.safeAreaInsets.bottom

        worldNode = SKNode()
        addChild(worldNode)

        buildHeaderCard()
        buildFooterCard()
        updateHUD()
        layoutBoard()
        startNewGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, !grid.isEmpty else { return }
        rebuildHUD()
        layoutBoard()
        rebuildAllNodes()
    }

    // MARK: - HUD: Header Card

    private func rebuildHUD() {
        headerCard?.removeFromParent()
        footerCard?.removeFromParent()
        buildHeaderCard()
        buildFooterCard()
        updateHUD()
    }

    private func buildHeaderCard() {
        let cardW = size.width - 24
        let cardH: CGFloat = 170
        let topY = size.height / 2 - safeTop - 8 - cardH / 2

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.42)
        card.strokeColor = UIColor(white: 1, alpha: 0.55)
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: topY)
        card.zPosition = 50
        addChild(card)
        headerCard = card

        let leftX = -cardW / 2 + 18
        let rightX = cardW / 2 - 18

        // Lives pill (heart icon + 5/6)
        let pillW: CGFloat = 84
        let pill = makePill(width: pillW, height: 30,
                            fill: UIColor(red: 0.99, green: 0.36, blue: 0.51, alpha: 0.95),
                            stroke: .clear)
        pill.position = CGPoint(x: leftX + pillW / 2, y: cardH / 2 - 24)
        card.addChild(pill)

        // Subtle drop shadow under the lives pill
        let pillShadow = SKShapeNode(rectOf: CGSize(width: pillW, height: 30), cornerRadius: 15)
        pillShadow.fillColor = UIColor(white: 0, alpha: 0.18)
        pillShadow.strokeColor = .clear
        pillShadow.position = CGPoint(x: leftX + pillW / 2, y: cardH / 2 - 24 - 2)
        pillShadow.zPosition = -1
        card.addChild(pillShadow)

        let heart = Icons.sprite(Icons.Name.life, size: 13, tint: .white)
        heart.position = CGPoint(x: -pillW / 2 + 16, y: 0)
        pill.addChild(heart)

        let livesL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesL.fontSize = 14
        livesL.fontColor = .white
        livesL.verticalAlignmentMode = .center
        livesL.horizontalAlignmentMode = .center
        livesL.position = CGPoint(x: 10, y: 0)
        pill.addChild(livesL)
        livesLabel = livesL

        // Moves badge card (with drop shadow)
        let movesBadgeW: CGFloat = 88
        let movesBadgeH: CGFloat = 64
        let badgeShadow = SKShapeNode(rectOf: CGSize(width: movesBadgeW, height: movesBadgeH), cornerRadius: 14)
        badgeShadow.fillColor = UIColor(white: 0, alpha: 0.18)
        badgeShadow.strokeColor = .clear
        badgeShadow.position = CGPoint(x: rightX - movesBadgeW / 2, y: cardH / 2 - movesBadgeH / 2 - 14 - 3)
        badgeShadow.zPosition = -1
        card.addChild(badgeShadow)

        let movesBadge = SKShapeNode(rectOf: CGSize(width: movesBadgeW, height: movesBadgeH), cornerRadius: 14)
        movesBadge.fillColor = UIColor(white: 1, alpha: 0.97)
        movesBadge.strokeColor = .clear
        movesBadge.position = CGPoint(x: rightX - movesBadgeW / 2, y: cardH / 2 - movesBadgeH / 2 - 14)
        card.addChild(movesBadge)

        let movesNum = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        movesNum.fontSize = 28
        movesNum.fontColor = UIColor(hex: "#0F172A")
        movesNum.verticalAlignmentMode = .center
        movesNum.horizontalAlignmentMode = .center
        movesNum.position = CGPoint(x: 0, y: 8)
        movesBadge.addChild(movesNum)
        movesValueLabel = movesNum

        let movesCap = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        movesCap.text = "Moves"
        movesCap.fontSize = 12
        movesCap.fontColor = UIColor(white: 0, alpha: 0.55)
        movesCap.verticalAlignmentMode = .center
        movesCap.horizontalAlignmentMode = .center
        movesCap.position = CGPoint(x: 0, y: -14)
        movesBadge.addChild(movesCap)

        // Level title (bolt icon + "Level N")
        let bolt = Icons.sprite(Icons.Name.level, size: 22, tint: UIColor(hex: "#FACC15"))
        bolt.position = CGPoint(x: leftX + 12, y: 14)
        card.addChild(bolt)

        let lvl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lvl.fontSize = 28
        lvl.fontColor = .white
        lvl.text = "Level \(levelNumber)"
        lvl.verticalAlignmentMode = .center
        lvl.horizontalAlignmentMode = .left
        lvl.position = CGPoint(x: leftX + 32, y: 14)
        card.addChild(lvl)
        levelLabel = lvl

        // Score caption + goal pill
        let scoreCap = SKLabelNode(fontNamed: "AvenirNext-Medium")
        scoreCap.text = "Score"
        scoreCap.fontSize = 14
        scoreCap.fontColor = UIColor(white: 1, alpha: 0.95)
        scoreCap.verticalAlignmentMode = .center
        scoreCap.horizontalAlignmentMode = .left
        scoreCap.position = CGPoint(x: leftX, y: -22)
        card.addChild(scoreCap)

        let goalPill = makePill(width: 130, height: 28,
                                fill: UIColor(white: 1, alpha: 0.85),
                                stroke: .clear)
        goalPill.position = CGPoint(x: leftX + 50 + 65, y: -22)
        card.addChild(goalPill)

        let target = Icons.sprite(Icons.Name.goal, size: 14, tint: UIColor(hex: "#EF4444"))
        target.position = CGPoint(x: -45, y: 0)
        goalPill.addChild(target)

        let gLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gLabel.fontSize = 13
        gLabel.fontColor = UIColor(hex: "#0F172A")
        gLabel.verticalAlignmentMode = .center
        gLabel.horizontalAlignmentMode = .center
        gLabel.position = CGPoint(x: 8, y: 0)
        goalPill.addChild(gLabel)
        goalLabel = gLabel

        // Total
        let totalCap = SKLabelNode(fontNamed: "AvenirNext-Medium")
        totalCap.text = "Total"
        totalCap.fontSize = 14
        totalCap.fontColor = UIColor(white: 1, alpha: 0.95)
        totalCap.verticalAlignmentMode = .center
        totalCap.horizontalAlignmentMode = .right
        totalCap.position = CGPoint(x: rightX - 70, y: -22)
        card.addChild(totalCap)

        let totalNum = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        totalNum.fontSize = 16
        totalNum.fontColor = .white
        totalNum.verticalAlignmentMode = .center
        totalNum.horizontalAlignmentMode = .right
        totalNum.position = CGPoint(x: rightX, y: -22)
        card.addChild(totalNum)
        totalLabel = totalNum

        // Star progress bar
        let trackW = cardW - 36
        let trackH: CGFloat = 8
        let trackY: CGFloat = -cardH / 2 + 22

        let track = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        track.fillColor = UIColor(white: 1, alpha: 0.25)
        track.strokeColor = .clear
        track.position = CGPoint(x: 0, y: trackY)
        card.addChild(track)
        progressTrack = track

        let fill = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        fill.fillColor = UIColor(hex: "#FBBF24")
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 0, y: trackY)
        fill.xScale = 0.0001
        card.addChild(fill)
        progressFill = fill

        for (idx, frac) in [0.33, 0.66, 1.0].enumerated() {
            let starNode = makeShinyStar(size: 22)
            let x = -trackW / 2 + trackW * CGFloat(frac)
            starNode.position = CGPoint(x: x, y: trackY)
            starNode.zPosition = 2
            card.addChild(starNode)

            // Stagger the pulse so the trio twinkles like a constellation
            let phase = Double(idx) * 0.45
            starNode.run(.sequence([.wait(forDuration: phase),
                                    .repeatForever(.sequence([
                                        .scale(to: 1.12, duration: 0.9),
                                        .scale(to: 1.0,  duration: 0.9)
                                    ]))]))

            // Occasional sparkle burst (radial dots that grow + fade)
            scheduleSparkle(on: starNode, delay: 1.5 + Double(idx) * 0.7)
        }
    }

    /// Builds a stack: glow halo → main gold star → subtle highlight → tiny sparkle layer.
    private func makeShinyStar(size: CGFloat) -> SKNode {
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
    private func starPath(size: CGFloat) -> CGPath {
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
    private func scheduleSparkle(on node: SKNode, delay: TimeInterval) {
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

    private func emitSparkle(on node: SKNode) {
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

    private func buildFooterCard() {
        let cardW = size.width - 24
        let cardH: CGFloat = 180
        let bottomY = -size.height / 2 + safeBottom + 8 + cardH / 2

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.42)
        card.strokeColor = UIColor(white: 1, alpha: 0.55)
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: bottomY)
        card.zPosition = 50
        addChild(card)
        footerCard = card

        let topRowY = cardH / 2 - 28
        let leftX = -cardW / 2 + 18
        let rightX = cardW / 2 - 18

        // Settings (gear) — light circle, soft slate icon (less aggressive than black)
        let slate = UIColor(hex: "#475569")
        let gear = makeSymbolCircle(symbol: Icons.Name.settings, diameter: 44,
                                    fill: UIColor(white: 1, alpha: 0.95),
                                    iconTint: slate,
                                    iconSize: 18,
                                    weight: .medium)
        gear.position = CGPoint(x: leftX + 22, y: topRowY)
        gear.name = "settingsButton"
        card.addChild(gear)

        // Cash pill — gold-accented "wallet" with banknote + amount + shadow
        let cashPillW: CGFloat = 168
        let cashPillH: CGFloat = 40

        let cashPillShadow = makePill(width: cashPillW, height: cashPillH,
                                      fill: UIColor(white: 0, alpha: 0.2),
                                      stroke: .clear)
        cashPillShadow.position = CGPoint(x: 0, y: topRowY - 3)
        cashPillShadow.zPosition = -1
        card.addChild(cashPillShadow)

        let cashPill = makePill(width: cashPillW, height: cashPillH,
                                fill: UIColor(white: 1, alpha: 0.97),
                                stroke: UIColor(hex: "#FFD700").withAlphaComponent(0.55))
        cashPill.lineWidth = 1.5
        cashPill.position = CGPoint(x: 0, y: topRowY)
        card.addChild(cashPill)

        // Gold gradient inset (a thin lighter pill on top to fake a soft sheen)
        let sheen = makePill(width: cashPillW - 4, height: cashPillH / 2,
                             fill: UIColor(hex: "#FFFBEB").withAlphaComponent(0.55),
                             stroke: .clear)
        sheen.position = CGPoint(x: 0, y: cashPillH / 4 - 2)
        cashPill.addChild(sheen)

        // Coin icon (gold banknote, prominent)
        let coinHalo = SKShapeNode(circleOfRadius: 14)
        coinHalo.fillColor = UIColor(hex: "#FEF3C7")
        coinHalo.strokeColor = UIColor(hex: "#FFD700").withAlphaComponent(0.5)
        coinHalo.lineWidth = 1
        coinHalo.position = CGPoint(x: -cashPillW / 2 + 22, y: 0)
        cashPill.addChild(coinHalo)

        let cashIcon = Icons.sprite(Icons.Name.cashFilled, size: 16,
                                    weight: .heavy,
                                    tint: UIColor(hex: "#D97706"))
        coinHalo.addChild(cashIcon)

        let cashL = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        cashL.fontSize = 19
        cashL.fontColor = UIColor(hex: "#0F172A")
        cashL.verticalAlignmentMode = .center
        cashL.horizontalAlignmentMode = .center
        cashL.position = CGPoint(x: 10, y: 0)
        cashPill.addChild(cashL)
        cashLabel = cashL

        // Cart — light circle, soft slate icon
        let cart = makeSymbolCircle(symbol: Icons.Name.cart, diameter: 44,
                                    fill: UIColor(white: 1, alpha: 0.95),
                                    iconTint: slate,
                                    iconSize: 18,
                                    weight: .medium)
        cart.position = CGPoint(x: rightX - 22, y: topRowY)
        cart.name = "cartButton"
        card.addChild(cart)

        // Booster row — softer pastel fills, smaller / lighter icons
        let boosters: [(symbol: String, label: String, fill: UIColor,
                        iconSize: CGFloat, iconWeight: UIImage.SymbolWeight,
                        iconTint: UIColor, chip: String, paid: Bool)] = [
            (Icons.Name.hammer,     "Hammer",  UIColor(hex: "#FB923C"), 22, .medium,    .white,                       "88",  true),
            (Icons.Name.swap,       "Swap",    UIColor(hex: "#FACC15"), 18, .regular,   UIColor(hex: "#1E293B"),      "130", true),
            (Icons.Name.shuffle,    "Shuffle", UIColor(hex: "#7DD3FC"), 22, .semibold,  .white,                       "2",   false),
            (Icons.Name.extraMoves, "+Moves",  UIColor(hex: "#F9A8D4"), 22, .heavy,     UIColor(hex: "#FACC15"),      "119", true),
            (Icons.Name.life,       "Life",    UIColor(hex: "#F9A8D4"), 20, .heavy,     UIColor(hex: "#EF4444"),      "152", true)
        ]

        let cellW = (cardW - 24) / CGFloat(boosters.count)
        let circleD: CGFloat = 52
        let rowY: CGFloat = -cardH / 2 + 56

        for (i, b) in boosters.enumerated() {
            let cx = -cardW / 2 + 12 + cellW * (CGFloat(i) + 0.5)

            // Drop shadow under circle
            let shadow = SKShapeNode(circleOfRadius: circleD / 2)
            shadow.fillColor = UIColor(white: 0, alpha: 0.18)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: cx, y: rowY + 8)
            shadow.zPosition = 1
            card.addChild(shadow)

            let circle = SKShapeNode(circleOfRadius: circleD / 2)
            circle.fillColor = b.fill
            circle.strokeColor = .clear
            circle.position = CGPoint(x: cx, y: rowY + 12)
            circle.zPosition = 2
            if b.label == "+Moves" {
                circle.name = "movesBoosterCircle"
                movesBoosterCircle = circle
            }
            card.addChild(circle)

            let icon = Icons.sprite(b.symbol, size: b.iconSize, weight: b.iconWeight, tint: b.iconTint)
            circle.addChild(icon)

            // Quantity badge — only on the +Moves booster. Shows currently selected
            // quantity (e.g. "+5"); tapping opens the picker popup.
            if b.label == "+Moves" {
                let badgeW: CGFloat = 28
                let badgeH: CGFloat = 18
                let badge = SKShapeNode(rectOf: CGSize(width: badgeW, height: badgeH), cornerRadius: badgeH / 2)
                badge.fillColor = UIColor(hex: "#22C55E")
                badge.strokeColor = .white
                badge.lineWidth = 1.2
                badge.position = CGPoint(x: circleD / 2 - 2, y: circleD / 2 - 2)
                badge.zPosition = 3
                badge.name = "movesQuantityBadge"
                circle.addChild(badge)
                movesQuantityBadge = badge

                badge.run(.repeatForever(.sequence([
                    .scale(to: 1.12, duration: 0.7),
                    .scale(to: 1.0, duration: 0.7)
                ])))

                let badgeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                badgeLabel.text = "+\(movesQuantity)"
                badgeLabel.fontSize = 11
                badgeLabel.fontColor = .white
                badgeLabel.verticalAlignmentMode = .center
                badgeLabel.horizontalAlignmentMode = .center
                badge.addChild(badgeLabel)
                movesQuantityBadgeLabel = badgeLabel
            }

            // Chip below circle
            let chipW: CGFloat = b.paid ? 54 : 30
            let chipH: CGFloat = 18
            let chip = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: chipH / 2)
            chip.fillColor = b.paid ? UIColor(white: 0, alpha: 0.7) : UIColor(white: 1, alpha: 0.85)
            chip.strokeColor = .clear
            chip.position = CGPoint(x: cx, y: rowY - 18)
            card.addChild(chip)

            if b.paid {
                // Programmatic gold coin — bypass SF Symbol multicolor weirdness
                let coin = SKShapeNode(circleOfRadius: 7)
                coin.fillColor = UIColor(hex: "#FFD700")
                coin.strokeColor = UIColor(hex: "#D97706")
                coin.lineWidth = 1
                coin.position = CGPoint(x: -16, y: 0)
                chip.addChild(coin)

                let dollar = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                dollar.text = "$"
                dollar.fontSize = 9
                dollar.fontColor = UIColor(hex: "#7C2D12")
                dollar.verticalAlignmentMode = .center
                dollar.horizontalAlignmentMode = .center
                coin.addChild(dollar)

                let chipL = SKLabelNode(fontNamed: "AvenirNext-Bold")
                chipL.text = b.chip
                chipL.fontSize = 11
                chipL.fontColor = .white
                chipL.verticalAlignmentMode = .center
                chipL.horizontalAlignmentMode = .center
                chipL.position = CGPoint(x: 6, y: 0)
                chip.addChild(chipL)
            } else {
                let chipL = SKLabelNode(fontNamed: "AvenirNext-Bold")
                chipL.text = b.chip
                chipL.fontSize = 11
                chipL.fontColor = UIColor(hex: "#0F172A")
                chipL.verticalAlignmentMode = .center
                chipL.horizontalAlignmentMode = .center
                chip.addChild(chipL)
            }

            // Booster name
            let nameL = SKLabelNode(fontNamed: "AvenirNext-Bold")
            nameL.text = b.label
            nameL.fontSize = 11
            nameL.fontColor = .white
            nameL.verticalAlignmentMode = .center
            nameL.horizontalAlignmentMode = .center
            nameL.position = CGPoint(x: cx, y: rowY - 38)
            card.addChild(nameL)
        }
    }

    // MARK: - HUD helpers

    private func makePill(width: CGFloat, height: CGFloat, fill: UIColor, stroke: UIColor) -> SKShapeNode {
        let pill = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        pill.fillColor = fill
        pill.strokeColor = stroke
        pill.lineWidth = stroke == .clear ? 0 : 1
        return pill
    }

    private func makeSymbolCircle(symbol: String, diameter: CGFloat, fill: UIColor,
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

    private func updateHUD() {
        movesValueLabel?.text = "\(movesLeft)"
        goalLabel?.text = "\(min(score, scoreTarget)) / \(scoreTarget)"
        livesLabel?.text = "\(lives)/\(livesMax)"
        totalLabel?.text = "\(totalScore)"
        cashLabel?.text = "\(cash)"

        if let track = progressTrack, let fill = progressFill {
            let frac = min(1.0, CGFloat(score) / CGFloat(scoreTarget))
            let trackW = track.frame.width
            fill.removeAllActions()
            fill.run(.scaleX(to: max(0.0001, frac), duration: 0.18))
            fill.position.x = -trackW / 2 + trackW * frac / 2
        }
    }

    // MARK: - Board layout

    private func layoutBoard() {
        let headerH: CGFloat = 170
        let footerH: CGFloat = 180
        let headerBottom = size.height / 2 - safeTop - 8 - headerH
        let footerTop = -size.height / 2 + safeBottom + 8 + footerH

        let pad: CGFloat = 14
        let safeWidth = size.width - pad * 2
        let safeHeight = (headerBottom - footerTop) - 16
        let side = min(safeWidth, safeHeight)
        gap = side * 0.012
        tileSize = (side - gap * CGFloat(cols + 1)) / CGFloat(cols)
        let boardSide = tileSize * CGFloat(cols) + gap * CGFloat(cols + 1)

        let centerY = (headerBottom + footerTop) / 2
        boardOrigin = CGPoint(
            x: -boardSide / 2 + gap + tileSize / 2,
            y: centerY + boardSide / 2 - gap - tileSize / 2
        )

        worldNode.childNode(withName: "boardBackdrop")?.removeFromParent()
        let bg = SKShapeNode(rectOf: CGSize(width: boardSide + 12, height: boardSide + 12), cornerRadius: 22)
        bg.name = "boardBackdrop"
        bg.position = CGPoint(x: 0, y: centerY)
        bg.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.92)
        bg.strokeColor = UIColor(white: 1, alpha: 0.08)
        bg.lineWidth = 1
        bg.zPosition = -10
        worldNode.addChild(bg)
    }

    private func point(forRow r: Int, col c: Int) -> CGPoint {
        CGPoint(x: boardOrigin.x + CGFloat(c) * (tileSize + gap),
                y: boardOrigin.y - CGFloat(r) * (tileSize + gap))
    }

    private func cellAt(_ point: CGPoint) -> Pos? {
        for r in 0..<rows {
            for c in 0..<cols {
                let p = self.point(forRow: r, col: c)
                let rect = CGRect(
                    x: p.x - tileSize / 2,
                    y: p.y - tileSize / 2,
                    width: tileSize,
                    height: tileSize
                )
                if rect.contains(point) { return Pos(r: r, c: c) }
            }
        }
        return nil
    }

    // MARK: - Game lifecycle

    private func startNewGame() {
        score = 0
        movesLeft = movesAtStart
        let layout = levelConfig.layout
        grid = Engine.createInitialGrid(rows: rows, cols: cols, colors: palette, mask: layout.mask)
        seedBlockers(layout: layout)
        seedStartingBombs(layout: layout)
        rebuildAllNodes()
    }

    /// Randomly tag playable cells with ice / lock blockers so the level reads as harder.
    private func seedBlockers(layout: LevelLayout) {
        guard layout.iceCount > 0 || layout.lockCount > 0 else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c] != nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle()

        // Ice
        for p in candidates.prefix(layout.iceCount) {
            grid[p.r][p.c]?.blocker = Blocker(type: .ice, hits: 2)
        }
        // Lock — start after the ice slice so they don't stack
        let lockSlice = candidates.dropFirst(layout.iceCount).prefix(layout.lockCount)
        for p in lockSlice {
            grid[p.r][p.c]?.blocker = Blocker(type: .lock, hits: 1)
        }
    }

    private func seedStartingBombs(layout: LevelLayout) {
        guard layout.startingBombs > 0 else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c] != nil && grid[r][c]?.blocker == nil {
                candidates.append(Pos(r: r, c: c))
            }
        }
        candidates.shuffle()
        for p in candidates.prefix(layout.startingBombs) {
            grid[p.r][p.c]?.special = .bomb
        }
    }

    private func rebuildAllNodes() {
        for row in nodes { for n in row { n?.removeFromParent() } }
        nodes = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c] else { continue }
                let node = makeTileNode(for: cell)
                node.position = point(forRow: r, col: c)
                worldNode.addChild(node)
                nodes[r][c] = node
            }
        }
    }

    private func makeTileNode(for cell: Cell) -> SKNode {
        let container = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize), cornerRadius: tileSize * 0.22)
        body.fillColor = skin.tileBg
        body.strokeColor = skin.tileBorder
        body.lineWidth = 1
        body.name = "body"
        container.addChild(body)

        let emoji = SKLabelNode(text: Theme.emoji(forColor: cell.color))
        emoji.fontSize = tileSize * 0.7
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .center
        emoji.name = "emoji"
        emoji.alpha = cell.blocker != nil ? 0.55 : 1.0
        container.addChild(emoji)

        // Ice overlay — translucent icy blue with frost border
        if let blocker = cell.blocker, blocker.type == .ice {
            let ice = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                                  cornerRadius: tileSize * 0.22)
            ice.fillColor = UIColor(hex: "#7DD3FC").withAlphaComponent(0.42)
            ice.strokeColor = UIColor(hex: "#3B82F6").withAlphaComponent(0.5)
            ice.lineWidth = 2
            ice.glowWidth = 2
            ice.zPosition = 4
            container.addChild(ice)

            // Frost crystal accent
            let frost = SKLabelNode(text: "❄︎")
            frost.fontSize = tileSize * 0.42
            frost.fontColor = UIColor.white.withAlphaComponent(0.9)
            frost.verticalAlignmentMode = .center
            frost.horizontalAlignmentMode = .center
            frost.zPosition = 5
            container.addChild(frost)
            frost.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.6, duration: 1.0),
                .fadeAlpha(to: 1.0, duration: 1.0)
            ])))
        }

        // Lock overlay — dark scrim with lock icon
        if let blocker = cell.blocker, blocker.type == .lock {
            let scrim = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                                    cornerRadius: tileSize * 0.22)
            scrim.fillColor = UIColor(white: 0, alpha: 0.45)
            scrim.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.5)
            scrim.lineWidth = 2
            scrim.zPosition = 4
            container.addChild(scrim)

            let lock = SKLabelNode(text: "🔒")
            lock.fontSize = tileSize * 0.5
            lock.verticalAlignmentMode = .center
            lock.horizontalAlignmentMode = .center
            lock.zPosition = 5
            container.addChild(lock)
        }

        // Bomb overlay — pulsing red glow + 💣 marker
        if cell.special == .bomb {
            let glow = SKShapeNode(circleOfRadius: tileSize * 0.42)
            glow.fillColor = UIColor(hex: "#EF4444").withAlphaComponent(0.35)
            glow.strokeColor = .clear
            glow.glowWidth = 6
            glow.blendMode = .add
            glow.zPosition = 1
            container.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .scale(to: 1.15, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))

            let bombMark = SKLabelNode(text: "💣")
            bombMark.fontSize = tileSize * 0.45
            bombMark.position = CGPoint(x: tileSize * 0.22, y: tileSize * 0.22)
            bombMark.zPosition = 2
            container.addChild(bombMark)
            bombMark.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 2, duration: 0.5),
                .moveBy(x: 0, y: -2, duration: 0.5)
            ])))
        }

        container.userData = NSMutableDictionary(dictionary: ["color": cell.color])
        return container
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // 0. End-level card takes precedence
        if let card = endLevelCard {
            _ = card.handleTap(at: p)
            return
        }

        // 1. Quantity popup is open — handle option pick or dismiss
        if let popup = quantityPopup {
            let local = popup.convert(p, from: self)
            for child in popup.children {
                guard let name = child.name, name.hasPrefix("qty:"),
                      child.contains(local) else { continue }
                let qStr = String(name.dropFirst(4))
                if let q = Int(qStr) { selectQuantity(q) }
                hideQuantityPopup()
                return
            }
            // tap outside popup → dismiss
            hideQuantityPopup()
            return
        }

        // 2. Tap on the +Moves quantity badge → open picker
        var node: SKNode? = atPoint(p)
        while let n = node {
            if n.name == "movesQuantityBadge" {
                showQuantityPopup()
                Effects.haptic(.light)
                return
            }
            if n.name == "movesBoosterCircle" {
                buyMoves()
                return
            }
            node = n.parent
        }

        // 3. Tile interaction
        guard !isResolving else { return }
        guard let pos = cellAt(p), grid[pos.r][pos.c] != nil else { return }
        dragStartPoint = p

        if let first = firstSelection {
            if first == pos {
                deselect()
                return
            }
            if isAdjacent(first, pos) {
                attemptSwap(first, pos)
                deselect()
            } else {
                deselect()
                select(pos)
            }
        } else {
            select(pos)
            Effects.haptic(.light)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isResolving, let t = touches.first, let start = dragStartPoint, let first = firstSelection else { return }
        let p = t.location(in: self)
        let dx = p.x - start.x
        let dy = p.y - start.y
        let threshold = tileSize * 0.4
        guard hypot(dx, dy) > threshold else { return }

        var target = first
        if abs(dx) > abs(dy) {
            target = Pos(r: first.r, c: first.c + (dx > 0 ? 1 : -1))
        } else {
            target = Pos(r: first.r + (dy < 0 ? 1 : -1), c: first.c)
        }
        if target.r >= 0, target.r < rows, target.c >= 0, target.c < cols, grid[target.r][target.c] != nil {
            attemptSwap(first, target)
        }
        deselect()
        dragStartPoint = nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragStartPoint = nil
    }

    private func isAdjacent(_ a: Pos, _ b: Pos) -> Bool {
        (a.r == b.r && abs(a.c - b.c) == 1) || (a.c == b.c && abs(a.r - b.r) == 1)
    }

    private func select(_ p: Pos) {
        firstSelection = p
        firstSelectionNode = nodes[p.r][p.c]
        if let body = firstSelectionNode?.childNode(withName: "body") as? SKShapeNode {
            body.strokeColor = skin.tileHighlight
            body.lineWidth = 3
            body.run(SKAction.repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.18),
                .scale(to: 1.0, duration: 0.18)
            ])), withKey: "pulse")
        }
    }

    private func deselect() {
        if let node = firstSelectionNode, let body = node.childNode(withName: "body") as? SKShapeNode {
            body.removeAction(forKey: "pulse")
            body.setScale(1.0)
            body.strokeColor = skin.tileBorder
            body.lineWidth = 1
        }
        firstSelection = nil
        firstSelectionNode = nil
    }

    // MARK: - Swap + cascade

    private func attemptSwap(_ a: Pos, _ b: Pos) {
        guard !isResolving, movesLeft > 0 else { return }
        isResolving = true
        cascadeDepth = 0

        let result = Engine.swapIfValid(grid, a, b)
        let nodeA = nodes[a.r][a.c]
        let nodeB = nodes[b.r][b.c]
        let posA = point(forRow: a.r, col: a.c)
        let posB = point(forRow: b.r, col: b.c)
        let dur: TimeInterval = 0.15

        if result.didSwap {
            grid = result.grid
            nodes[a.r][a.c] = nodeB
            nodes[b.r][b.c] = nodeA
            movesLeft -= 1
            Effects.haptic(.light)
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.resolveCascade()
            }
        } else {
            Effects.haptic(.soft)
            nodeA?.run(.sequence([.move(to: posB, duration: dur), .move(to: posA, duration: dur)]))
            nodeB?.run(.sequence([.move(to: posA, duration: dur), .move(to: posB, duration: dur)])) { [weak self] in
                self?.isResolving = false
            }
        }
    }

    private func resolveCascade() {
        let groups = Engine.findMatchGroups(grid)
        guard !groups.isEmpty else {
            isResolving = false
            checkLevelEnd()
            return
        }

        cascadeDepth += 1
        let depth = cascadeDepth

        // Build the full cleared set (groups + special detonations)
        var matches = Set<Pos>()
        for g in groups { matches.formUnion(g) }
        matches = Engine.expandMatchesWithSpecials(grid, matches)

        // Detect a 5+ run → bomb candidate (spawned at the run's centre after clear)
        var bombSpawnPos: Pos? = nil
        if let runLen = levelConfig.bombSpawnRunLength {
            for g in groups where g.count >= runLen {
                bombSpawnPos = g[g.count / 2]
                break
            }
        }

        let cleared = matches.count
        let multiplier = depth
        let pointsPerTile = 10

        // Compute centroid of cleared positions in scene coords
        var sx: CGFloat = 0
        var sy: CGFloat = 0
        for p in matches {
            let pt = point(forRow: p.r, col: p.c)
            sx += pt.x
            sy += pt.y
        }
        let centroid = CGPoint(x: sx / CGFloat(cleared), y: sy / CGFloat(cleared))

        // Animate clear + spawn per-tile bursts
        let clearGroup = SKAction.group([
            .scale(to: 1.25, duration: 0.08),
            .fadeOut(withDuration: 0.16)
        ])

        var nodesToRemove: [SKNode] = []
        for p in matches {
            if let n = nodes[p.r][p.c] {
                nodesToRemove.append(n)
                nodes[p.r][p.c] = nil

                // Tile-color particle burst at this tile
                let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
                let burst = Effects.makeTileBurst(tint: tint)
                burst.position = n.position
                worldNode.addChild(burst)
                burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
            }
        }

        // Score popup at centroid
        let added = cleared * pointsPerTile * multiplier
        score += added
        let popupColor: UIColor = depth >= 2 ? UIColor(hex: "#FACC15") : .white
        Effects.showScorePopup(added, at: centroid, in: self, color: popupColor)

        // Banner: combo (depth 2+) takes priority, else big-clear (4+ tiles)
        if let combo = Effects.comboPhrase(forDepth: depth) {
            Effects.showComboBanner(text: combo.text, color: combo.color, in: self)
            Effects.notify(.success)
        } else if let big = Effects.bigClearPhrase(forCount: cleared) {
            Effects.showComboBanner(text: big.text, color: big.color, in: self)
            Effects.haptic(.medium)
        } else {
            Effects.haptic(.medium)
        }

        // Confetti for big chains or massive single clears
        if depth >= 3 || cleared >= 6 {
            spawnConfetti()
        }

        // Screen shake for sizable clears
        if cleared >= 4 || depth >= 2 {
            Effects.shake(worldNode,
                          intensity: cleared >= 6 ? 12 : 7,
                          duration: 0.28)
        }

        Engine.clearMatches(&grid, matches: matches)

        // Spawn a bomb tile at the centre of any 5+ run
        if let bp = bombSpawnPos {
            // Re-pick a color from the run's neighbours (any will do; use palette[0] as fallback)
            let color = palette.randomElement() ?? palette[0]
            grid[bp.r][bp.c] = Cell(id: "bomb-\(Int.random(in: 0..<99999))",
                                     color: color, special: .bomb, kind: .normal)
        }

        let removeAction = SKAction.sequence([clearGroup, .removeFromParent()])
        for n in nodesToRemove { n.run(removeAction) }

        run(.wait(forDuration: 0.18)) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    // MARK: - Level end

    private func checkLevelEnd() {
        guard !levelEnded else { return }
        if score >= scoreTarget {
            endLevel(won: true)
        } else if movesLeft <= 0 {
            endLevel(won: false)
        }
    }

    private func endLevel(won: Bool) {
        levelEnded = true
        isResolving = true

        let stars: Int = {
            guard won else { return 0 }
            let t = levelConfig.starThresholds
            if score >= t.three { return 3 }
            if score >= t.two { return 2 }
            return 1
        }()

        let outcome: EndLevelCard.Outcome = won
            ? .win(stars: stars, score: score, target: scoreTarget)
            : .lose(score: score, target: scoreTarget)

        let card = EndLevelCard(outcome: outcome, sceneSize: size)
        card.position = .zero
        card.alpha = 0
        card.setScale(0.7)
        addChild(card)
        card.run(.group([
            .fadeIn(withDuration: 0.2),
            .scale(to: 1.0, duration: 0.2)
        ]))
        endLevelCard = card

        card.onPrimary = { [weak self] in
            guard let self = self else { return }
            if won, self.levelNumber < Levels.count {
                self.advanceToLevel(self.levelNumber + 1)
            } else {
                self.resetLevel()
            }
        }
        card.onSecondary = { [weak self] in
            self?.resetLevel()
        }

        if won {
            Effects.notify(.success)
        } else {
            Effects.notify(.error)
        }
    }

    private func advanceToLevel(_ n: Int) {
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        deselect()
        levelConfig = Levels.config(for: n)
        rebuildHUD()
        layoutBoard()
        startNewGame()
    }

    private func resetLevel() {
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        deselect()
        rebuildHUD()
        layoutBoard()
        startNewGame()
    }

    // MARK: - +Moves quantity selector

    private func showQuantityPopup() {
        hideQuantityPopup()
        guard let circle = movesBoosterCircle else { return }

        // Convert the circle's position into scene coords (it lives inside footerCard)
        let circleScenePos = circle.parent?.convert(circle.position, to: self) ?? circle.position

        let popupW: CGFloat = 240
        let popupH: CGFloat = 86
        let popupY = circleScenePos.y + 78

        let popup = SKNode()
        popup.position = CGPoint(x: circleScenePos.x, y: popupY)
        popup.zPosition = 1000
        popup.alpha = 0
        popup.setScale(0.4)

        // Card background
        let bg = SKShapeNode(rectOf: CGSize(width: popupW, height: popupH), cornerRadius: 16)
        bg.fillColor = UIColor(white: 1, alpha: 0.97)
        bg.strokeColor = UIColor(white: 0, alpha: 0.08)
        bg.lineWidth = 1
        bg.zPosition = 0
        popup.addChild(bg)

        // Drop shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: popupW, height: popupH), cornerRadius: 16)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        popup.addChild(shadow)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = "Buy moves"
        title.fontSize = 11
        title.fontColor = UIColor(hex: "#475569")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: popupH / 2 - 16)
        popup.addChild(title)

        // Options as small dotted pills
        let pillW: CGFloat = 36
        let pillH: CGFloat = 30
        let spacing: CGFloat = 8
        let totalW = CGFloat(quantityOptions.count) * pillW + CGFloat(quantityOptions.count - 1) * spacing
        var x = -totalW / 2 + pillW / 2

        for opt in quantityOptions {
            let isSelected = opt == movesQuantity
            let pill = SKShapeNode(rectOf: CGSize(width: pillW, height: pillH), cornerRadius: 9)
            pill.fillColor = isSelected ? UIColor(hex: "#F472B6") : UIColor(white: 0, alpha: 0.05)
            pill.strokeColor = isSelected ? .clear : UIColor(white: 0, alpha: 0.12)
            pill.lineWidth = 1
            pill.position = CGPoint(x: x, y: -10)
            pill.name = "qty:\(opt)"
            popup.addChild(pill)

            let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            l.text = "\(opt)"
            l.fontSize = 14
            l.fontColor = isSelected ? .white : UIColor(hex: "#0F172A")
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            pill.addChild(l)

            x += pillW + spacing
        }

        // Pointer (small triangle pointing down at the badge) — drawn as a rotated square
        let pointer = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
        pointer.fillColor = UIColor(white: 1, alpha: 0.97)
        pointer.strokeColor = .clear
        pointer.position = CGPoint(x: 0, y: -popupH / 2 + 4)
        pointer.zRotation = .pi / 4
        pointer.zPosition = -1
        popup.addChild(pointer)

        addChild(popup)
        quantityPopup = popup

        popup.run(.group([
            .scale(to: 1.0, duration: 0.18),
            .fadeIn(withDuration: 0.12)
        ]))
    }

    private func hideQuantityPopup() {
        guard let popup = quantityPopup else { return }
        quantityPopup = nil
        popup.run(.sequence([
            .group([
                .scale(to: 0.4, duration: 0.12),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ]))
    }

    private func selectQuantity(_ q: Int) {
        movesQuantity = q
        movesQuantityBadgeLabel?.text = "+\(q)"
        // little pop on the badge to confirm the change
        movesQuantityBadge?.run(.sequence([
            .scale(to: 1.25, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ]))
        Effects.haptic(.light)
    }

    private func buyMoves() {
        guard cash >= movesBuyCost else {
            Effects.haptic(.soft)
            // Briefly shake the cash pill to signal "not enough"
            if let pill = footerCard?.children.first(where: { ($0 as? SKShapeNode)?.fillColor == UIColor(white: 1, alpha: 0.97) }) {
                Effects.shake(pill, intensity: 4, duration: 0.2)
            }
            return
        }
        cash -= movesBuyCost
        movesLeft += movesQuantity
        Effects.haptic(.medium)
        Effects.notify(.success)

        // Floating "+N moves" feedback above the booster
        if let circle = movesBoosterCircle {
            let pos = circle.parent?.convert(circle.position, to: self) ?? .zero
            Effects.showScorePopup(movesQuantity,
                                   at: CGPoint(x: pos.x, y: pos.y + 36),
                                   in: self,
                                   color: UIColor(hex: "#F472B6"))
        }

        // Bounce the booster circle
        movesBoosterCircle?.run(.sequence([
            .scale(to: 1.18, duration: 0.1),
            .scale(to: 1.0, duration: 0.14)
        ]))
    }

    private func spawnConfetti() {
        let confetti = Effects.makeConfetti(width: size.width)
        confetti.position = CGPoint(x: 0, y: size.height / 2 + 20)
        addChild(confetti)
        confetti.run(.sequence([.wait(forDuration: 2.6), .removeFromParent()]))
    }

    private func applyCollapseAndRefill() {
        let oldGrid = grid
        let newGrid = Engine.collapseAndRefill(grid, colors: palette, mask: levelConfig.layout.mask)
        grid = newGrid

        var newNodes: [[SKNode?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        let idToNode = nodeIdMap(in: oldGrid)

        let fallDur: TimeInterval = 0.22

        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = newGrid[r][c] else { continue }
                if let existing = idToNode[cell.id] {
                    newNodes[r][c] = existing
                    existing.run(.move(to: point(forRow: r, col: c), duration: fallDur))
                } else {
                    let node = makeTileNode(for: cell)
                    let spawnY = size.height / 2 + tileSize
                    node.position = CGPoint(x: point(forRow: r, col: c).x, y: spawnY)
                    worldNode.addChild(node)
                    node.run(.move(to: point(forRow: r, col: c), duration: fallDur))
                    newNodes[r][c] = node
                }
            }
        }
        nodes = newNodes

        run(.wait(forDuration: fallDur + 0.02)) { [weak self] in
            self?.resolveCascade()
        }
    }

    private func nodeIdMap(in oldGrid: Grid) -> [String: SKNode] {
        var map: [String: SKNode] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                if let cell = oldGrid[r][c], let n = nodes[r][c] {
                    map[cell.id] = n
                }
            }
        }
        return map
    }
}
