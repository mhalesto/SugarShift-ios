import SpriteKit

final class GameScene: SKScene {

    // MARK: - Config

    private let rows = 8
    private let cols = 8
    private let palette = Array(Theme.colors.prefix(6))
    private let skin = BoardSkin.midnight

    // Level params (placeholder until levels.ts is ported)
    private let levelNumber = 1
    private let movesAtStart = 21
    private let scoreTarget = 2000

    // Placeholder economy state (UI only, not wired to gameplay)
    private var lives = 5
    private let livesMax = 6
    private var totalScore = 34030
    private var cash = 2553

    // MARK: - State

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

    private var score: Int = 0 { didSet { updateHUD() } }
    private var movesLeft: Int = 0 { didSet { updateHUD() } }

    // HUD nodes
    private var headerCard: SKShapeNode!
    private var footerCard: SKShapeNode!

    private var livesLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!
    private var goalLabel: SKLabelNode!
    private var totalLabel: SKLabelNode!
    private var movesValueLabel: SKLabelNode!
    private var scoreSubLabel: SKLabelNode!

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

        // Lives pill (top-left)
        let pill = makePill(
            width: 78,
            height: 30,
            fill: UIColor(red: 0.99, green: 0.36, blue: 0.51, alpha: 0.95),
            stroke: .clear
        )
        pill.position = CGPoint(x: leftX + 39, y: cardH / 2 - 24)
        card.addChild(pill)

        let heart = SKLabelNode(text: "❤️")
        heart.fontSize = 14
        heart.verticalAlignmentMode = .center
        heart.horizontalAlignmentMode = .center
        heart.position = CGPoint(x: -22, y: 0)
        pill.addChild(heart)

        let livesL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesL.fontSize = 14
        livesL.fontColor = .white
        livesL.verticalAlignmentMode = .center
        livesL.horizontalAlignmentMode = .center
        livesL.position = CGPoint(x: 8, y: 0)
        pill.addChild(livesL)
        livesLabel = livesL

        // Moves badge card (top-right)
        let movesBadgeW: CGFloat = 88
        let movesBadgeH: CGFloat = 64
        let movesBadge = SKShapeNode(rectOf: CGSize(width: movesBadgeW, height: movesBadgeH), cornerRadius: 14)
        movesBadge.fillColor = UIColor(white: 1, alpha: 0.92)
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

        // Level title row (left, below lives)
        let bolt = SKLabelNode(text: "⚡️")
        bolt.fontSize = 24
        bolt.verticalAlignmentMode = .center
        bolt.horizontalAlignmentMode = .left
        bolt.position = CGPoint(x: leftX, y: 14)
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

        // Score + goal pill
        let scoreCap = SKLabelNode(fontNamed: "AvenirNext-Medium")
        scoreCap.text = "Score"
        scoreCap.fontSize = 14
        scoreCap.fontColor = UIColor(white: 1, alpha: 0.95)
        scoreCap.verticalAlignmentMode = .center
        scoreCap.horizontalAlignmentMode = .left
        scoreCap.position = CGPoint(x: leftX, y: -22)
        card.addChild(scoreCap)

        let goalPill = makePill(
            width: 120,
            height: 28,
            fill: UIColor(white: 1, alpha: 0.85),
            stroke: .clear
        )
        goalPill.position = CGPoint(x: leftX + 50 + 60, y: -22)
        card.addChild(goalPill)

        let target = SKLabelNode(text: "🎯")
        target.fontSize = 14
        target.verticalAlignmentMode = .center
        target.horizontalAlignmentMode = .center
        target.position = CGPoint(x: -40, y: 0)
        goalPill.addChild(target)

        let gLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gLabel.fontSize = 13
        gLabel.fontColor = UIColor(hex: "#0F172A")
        gLabel.verticalAlignmentMode = .center
        gLabel.horizontalAlignmentMode = .center
        gLabel.position = CGPoint(x: 8, y: 0)
        goalPill.addChild(gLabel)
        goalLabel = gLabel

        // Total (right side, below moves badge)
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

        // (intentionally no duplicate "Score 0" sub-label — score lives in the goal pill)
        scoreSubLabel = SKLabelNode()

        // Star progress bar across bottom of card
        let trackW = cardW - 36
        let trackH: CGFloat = 8
        let trackY: CGFloat = -cardH / 2 + 22

        let track = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: trackH / 2)
        track.fillColor = UIColor(white: 1, alpha: 0.1)
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

        for (i, frac) in [0.33, 0.66, 1.0].enumerated() {
            let star = SKLabelNode(text: "⭐️")
            star.fontSize = 16
            star.verticalAlignmentMode = .center
            star.horizontalAlignmentMode = .center
            let x = -trackW / 2 + trackW * CGFloat(frac)
            star.position = CGPoint(x: x, y: trackY)
            star.zPosition = 1
            star.alpha = 0.7
            star.name = "star\(i)"
            card.addChild(star)
        }

        updateHUD()
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

        // Settings (gear)
        let gear = makeIconCircle(symbol: "⚙︎", diameter: 42, fill: UIColor(white: 1, alpha: 0.85), iconColor: UIColor(hex: "#0F172A"))
        gear.position = CGPoint(x: leftX + 22, y: topRowY)
        gear.name = "settingsButton"
        card.addChild(gear)

        // Cash pill (center)
        let cashPill = makePill(
            width: 130,
            height: 36,
            fill: UIColor(white: 1, alpha: 0.92),
            stroke: .clear
        )
        cashPill.position = CGPoint(x: 0, y: topRowY)
        card.addChild(cashPill)

        let cashIcon = SKLabelNode(text: "💰")
        cashIcon.fontSize = 16
        cashIcon.verticalAlignmentMode = .center
        cashIcon.horizontalAlignmentMode = .center
        cashIcon.position = CGPoint(x: -38, y: 0)
        cashPill.addChild(cashIcon)

        let cashL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        cashL.fontSize = 16
        cashL.fontColor = UIColor(hex: "#0F172A")
        cashL.verticalAlignmentMode = .center
        cashL.horizontalAlignmentMode = .center
        cashL.position = CGPoint(x: 8, y: 0)
        cashPill.addChild(cashL)
        cashLabel = cashL

        // Cart (right)
        let cart = makeIconCircle(symbol: "🛒", diameter: 42, fill: UIColor(white: 1, alpha: 0.85), iconColor: UIColor(hex: "#0F172A"))
        cart.position = CGPoint(x: rightX - 22, y: topRowY)
        cart.name = "cartButton"
        card.addChild(cart)

        // Booster row — chips show 💰 price for paid items, plain count for owned (shuffle)
        let boosters: [(symbol: String, label: String, fill: UIColor, chip: String, paid: Bool)] = [
            ("🔨", "Hammer",  UIColor(hex: "#F97316"), "88",  true),
            ("✋", "Swap",    UIColor(hex: "#FBBF24"), "130", true),
            ("🔀", "Shuffle", UIColor(hex: "#60A5FA"), "2",   false),
            ("⚡️", "+Moves",  UIColor(hex: "#F472B6"), "119", true),
            ("❤️", "Life",    UIColor(hex: "#F472B6"), "152", true)
        ]

        let cellW = (cardW - 24) / CGFloat(boosters.count)
        let circleD: CGFloat = 52
        let rowY: CGFloat = -cardH / 2 + 56

        for (i, b) in boosters.enumerated() {
            let cx = -cardW / 2 + 12 + cellW * (CGFloat(i) + 0.5)

            let circle = SKShapeNode(circleOfRadius: circleD / 2)
            circle.fillColor = b.fill
            circle.strokeColor = .clear
            circle.position = CGPoint(x: cx, y: rowY + 12)
            card.addChild(circle)

            let icon = SKLabelNode(text: b.symbol)
            icon.fontSize = 24
            icon.verticalAlignmentMode = .center
            icon.horizontalAlignmentMode = .center
            circle.addChild(icon)

            // "+" badge
            let badge = SKShapeNode(circleOfRadius: 9)
            badge.fillColor = UIColor(hex: "#22C55E")
            badge.strokeColor = UIColor(white: 0, alpha: 0.25)
            badge.lineWidth = 1
            badge.position = CGPoint(x: circleD / 2 - 4, y: circleD / 2 - 4)
            circle.addChild(badge)

            let plus = SKLabelNode(fontNamed: "AvenirNext-Bold")
            plus.text = "+"
            plus.fontSize = 13
            plus.fontColor = .white
            plus.verticalAlignmentMode = .center
            plus.horizontalAlignmentMode = .center
            badge.addChild(plus)

            // Chip below circle: dark pill with 💰+price (paid) or plain count (owned)
            let chipW: CGFloat = b.paid ? 50 : 28
            let chipH: CGFloat = 18
            let chip = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: chipH / 2)
            chip.fillColor = b.paid ? UIColor(white: 0, alpha: 0.7) : UIColor(white: 1, alpha: 0.85)
            chip.strokeColor = .clear
            chip.position = CGPoint(x: cx, y: rowY - 18)
            card.addChild(chip)

            if b.paid {
                let coin = SKLabelNode(text: "💰")
                coin.fontSize = 9
                coin.verticalAlignmentMode = .center
                coin.horizontalAlignmentMode = .center
                coin.position = CGPoint(x: -14, y: 0)
                chip.addChild(coin)

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

    private func makeIconCircle(symbol: String, diameter: CGFloat, fill: UIColor, iconColor: UIColor = .white) -> SKNode {
        let node = SKNode()
        let bg = SKShapeNode(circleOfRadius: diameter / 2)
        bg.fillColor = fill
        bg.strokeColor = .clear
        node.addChild(bg)
        let label = SKLabelNode(text: symbol)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 18
        label.fontColor = iconColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        return node
    }

    private func updateHUD() {
        movesValueLabel?.text = "\(movesLeft)"
        goalLabel?.text = "\(min(score, scoreTarget)) / \(scoreTarget)"
        scoreSubLabel?.text = "Score \(score)"
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

        childNode(withName: "boardBackdrop")?.removeFromParent()
        let bg = SKShapeNode(rectOf: CGSize(width: boardSide + 12, height: boardSide + 12), cornerRadius: 22)
        bg.name = "boardBackdrop"
        bg.position = CGPoint(x: 0, y: centerY)
        bg.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.92)
        bg.strokeColor = UIColor(white: 1, alpha: 0.08)
        bg.lineWidth = 1
        bg.zPosition = -10
        addChild(bg)
    }

    private func point(forRow r: Int, col c: Int) -> CGPoint {
        let x = boardOrigin.x + CGFloat(c) * (tileSize + gap)
        let y = boardOrigin.y - CGFloat(r) * (tileSize + gap)
        return CGPoint(x: x, y: y)
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
        grid = Engine.createInitialGrid(rows: rows, cols: cols, colors: palette)
        rebuildAllNodes()
    }

    private func rebuildAllNodes() {
        for row in nodes { for n in row { n?.removeFromParent() } }
        nodes = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c] else { continue }
                let node = makeTileNode(for: cell)
                node.position = point(forRow: r, col: c)
                addChild(node)
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
        container.addChild(emoji)

        container.userData = NSMutableDictionary(dictionary: ["color": cell.color])
        return container
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

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
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.resolveCascade()
            }
        } else {
            nodeA?.run(.sequence([.move(to: posB, duration: dur), .move(to: posA, duration: dur)]))
            nodeB?.run(.sequence([.move(to: posA, duration: dur), .move(to: posB, duration: dur)])) { [weak self] in
                self?.isResolving = false
            }
        }
    }

    private func resolveCascade() {
        let matches = Engine.findMatches(grid)
        guard !matches.isEmpty else {
            isResolving = false
            return
        }

        let clearGroup = SKAction.group([
            .scale(to: 1.2, duration: 0.08),
            .fadeOut(withDuration: 0.16)
        ])

        var nodesToRemove: [SKNode] = []
        for p in matches {
            if let n = nodes[p.r][p.c] {
                nodesToRemove.append(n)
                nodes[p.r][p.c] = nil
            }
        }

        score += matches.count * 10
        Engine.clearMatches(&grid, matches: matches)

        let removeAction = SKAction.sequence([clearGroup, .removeFromParent()])
        for n in nodesToRemove { n.run(removeAction) }

        run(.wait(forDuration: 0.18)) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    private func applyCollapseAndRefill() {
        let oldGrid = grid
        let newGrid = Engine.collapseAndRefill(grid, colors: palette)
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
                    addChild(node)
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
