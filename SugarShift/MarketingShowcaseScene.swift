#if DEBUG
import SpriteKit
import UIKit

enum SugarShiftMarketingSceneKind: String, CaseIterable {
    case portal = "portal"
    case comboRush = "combo-rush"
    case bombStorm = "bomb-storm"
    case frostLocks = "frost-locks"
    case shapeWorlds = "shape-worlds"
    case lightning = "lightning"
    case boosters = "boosters"
    case crown = "crown"
    /// Marquee mechanic shot: a 2×2 square match hatching fish seekers.
    case fishHero = "fish-hero"
    /// Shared daily challenge shot: one seeded board for every player.
    case dailyBoard = "daily-board"

    static var current: SugarShiftMarketingSceneKind? {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "--sugarshift-marketing-scene") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return SugarShiftMarketingSceneKind(rawValue: arguments[valueIndex])
    }

    var level: Int {
        switch self {
        case .portal: 7
        case .comboRush: 13
        case .bombStorm: 43
        case .frostLocks: 35
        case .shapeWorlds: 50
        case .lightning: 45
        case .boosters: 28
        case .crown: 100
        case .fishHero: 10
        case .dailyBoard: Levels.dailyChallenge().level
        }
    }

    var title: String {
        switch self {
        case .portal: "SugarShift"
        case .comboRush: "Sugar Rush x7"
        case .bombStorm: "Bomb Storm"
        case .frostLocks: "Frost & Locks"
        case .shapeWorlds: "Every Board Twists"
        case .lightning: "Lightning Level"
        case .boosters: "Booster Save"
        case .crown: "Sugar Crown"
        case .fishHero: "Fish to the Rescue"
        case .dailyBoard: "Today's Board"
        }
    }

    var subtitle: String {
        switch self {
        case .portal: "Level \(level) • Donut board"
        case .comboRush: "Level \(level) • Cross-board chain"
        case .bombStorm: "Level \(level) • Four bombs armed"
        case .frostLocks: "Level \(level) • Frozen heart"
        case .shapeWorlds: "Level \(level) • Ultimate crown"
        case .lightning: "Level \(level) • Minimum moves"
        case .boosters: "Level \(level) • Combo rescue"
        case .crown: "Level \(level) • Final candy vault"
        case .fishHero: "Level \(level) • 2×2 square magic"
        case .dailyBoard: "Board #\(Levels.dailyChallenge().number) • Identical worldwide"
        }
    }

    var comboText: String {
        switch self {
        case .portal: "READY?"
        case .comboRush: "SUGAR RUSH!"
        case .bombStorm: "BOOM x4!"
        case .frostLocks: "CRACK IT!"
        case .shapeWorlds: "100 LEVELS"
        case .lightning: "CHAIN IT!"
        case .boosters: "+5 MOVES"
        case .crown: "UNREAL!"
        case .fishHero: "FISH!"
        case .dailyBoard: "SAME BOARD!"
        }
    }

    var accent: UIColor {
        switch self {
        case .portal: UIColor(hex: "#F472B6")
        case .comboRush: UIColor(hex: "#EC4899")
        case .bombStorm: UIColor(hex: "#F97316")
        case .frostLocks: UIColor(hex: "#38BDF8")
        case .shapeWorlds: UIColor(hex: "#A78BFA")
        case .lightning: UIColor(hex: "#FACC15")
        case .boosters: UIColor(hex: "#34D399")
        case .crown: UIColor(hex: "#F59E0B")
        case .fishHero: UIColor(hex: "#22D3EE")
        case .dailyBoard: UIColor(hex: "#34D399")
        }
    }

    var gradient: [UIColor] {
        switch self {
        case .portal: [UIColor(hex: "#7C3AED"), UIColor(hex: "#EC4899"), UIColor(hex: "#22D3EE")]
        case .comboRush: [UIColor(hex: "#831843"), UIColor(hex: "#EC4899"), UIColor(hex: "#FBCFE8")]
        case .bombStorm: [UIColor(hex: "#431407"), UIColor(hex: "#EA580C"), UIColor(hex: "#FACC15")]
        case .frostLocks: [UIColor(hex: "#0F172A"), UIColor(hex: "#0284C7"), UIColor(hex: "#BAE6FD")]
        case .shapeWorlds: [UIColor(hex: "#312E81"), UIColor(hex: "#7C3AED"), UIColor(hex: "#F0ABFC")]
        case .lightning: [UIColor(hex: "#111827"), UIColor(hex: "#F59E0B"), UIColor(hex: "#22D3EE")]
        case .boosters: [UIColor(hex: "#064E3B"), UIColor(hex: "#10B981"), UIColor(hex: "#A7F3D0")]
        case .crown: [UIColor(hex: "#1E1B4B"), UIColor(hex: "#6366F1"), UIColor(hex: "#F59E0B")]
        case .fishHero: [UIColor(hex: "#0F766E"), UIColor(hex: "#22D3EE"), UIColor(hex: "#F472B6")]
        case .dailyBoard: [UIColor(hex: "#065F46"), UIColor(hex: "#34D399"), UIColor(hex: "#FDE68A")]
        }
    }
}

final class SugarShiftMarketingShowcaseViewController: UIViewController {
    private let kind: SugarShiftMarketingSceneKind
    private let gradient = CAGradientLayer()
    private var skView: SKView!

    init(kind: SugarShiftMarketingSceneKind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.kind = .portal
        super.init(coder: coder)
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        gradient.colors = kind.gradient.map(\.cgColor)
        gradient.locations = [0.0, 0.52, 1.0]
        gradient.startPoint = CGPoint(x: 0.12, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.92, y: 1.0)
        view.layer.addSublayer(gradient)

        let sk = SKView(frame: view.bounds)
        sk.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sk.allowsTransparency = true
        sk.backgroundColor = .clear
        sk.ignoresSiblingOrder = true
        sk.showsFPS = false
        sk.showsNodeCount = false
        view.addSubview(sk)
        skView = sk

        let scene = SugarShiftMarketingShowcaseScene(size: sk.bounds.size, kind: kind)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        sk.presentScene(scene)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}

final class SugarShiftMarketingShowcaseScene: SKScene {
    private let kind: SugarShiftMarketingSceneKind
    private let config: LevelConfig

    init(size: CGSize, kind: SugarShiftMarketingSceneKind) {
        self.kind = kind
        self.config = Levels.config(for: kind.level)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        self.kind = .portal
        self.config = Levels.config(for: SugarShiftMarketingSceneKind.portal.level)
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        removeAllChildren()
        buildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        removeAllChildren()
        buildScene()
    }

    private func buildScene() {
        drawDepthBackground()
        drawHeader()
        drawBoard()
        drawActionOverlays()
        drawFooter()
    }

    private func drawDepthBackground() {
        let world = SKNode()
        world.zPosition = -20
        addChild(world)

        for i in 0..<18 {
            let radius = CGFloat(18 + (i % 5) * 12)
            let orb = SKShapeNode(circleOfRadius: radius)
            orb.fillColor = UIColor.white.withAlphaComponent(CGFloat(0.06 + Double(i % 4) * 0.018))
            orb.strokeColor = .clear
            orb.glowWidth = 8
            let x = CGFloat.random(in: -size.width * 0.55...size.width * 0.55)
            let y = CGFloat.random(in: -size.height * 0.48...size.height * 0.48)
            orb.position = CGPoint(x: x, y: y)
            orb.zPosition = -8
            world.addChild(orb)
        }

        let tunnel = SKShapeNode(circleOfRadius: min(size.width, size.height) * 0.45)
        tunnel.fillColor = .clear
        tunnel.strokeColor = UIColor.white.withAlphaComponent(0.10)
        tunnel.lineWidth = 18
        tunnel.glowWidth = 26
        tunnel.position = CGPoint(x: 0, y: size.height * 0.08)
        tunnel.zPosition = -7
        tunnel.setScale(1.25)
        addChild(tunnel)

        for i in 0..<9 {
            let ring = SKShapeNode(circleOfRadius: min(size.width, size.height) * CGFloat(0.16 + Double(i) * 0.045))
            ring.fillColor = .clear
            ring.strokeColor = kind.accent.withAlphaComponent(CGFloat(max(0.02, 0.16 - Double(i) * 0.014)))
            ring.lineWidth = 2
            ring.position = CGPoint(x: 0, y: size.height * 0.08)
            ring.zPosition = -6
            addChild(ring)
        }
    }

    private func drawHeader() {
        let topY = size.height / 2 - 58
        let header = SKNode()
        header.zPosition = 80
        addChild(header)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = kind.title
        title.fontSize = isPad ? 32 : 28
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -size.width / 2 + 28, y: topY)
        header.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = kind.subtitle
        subtitle.fontSize = isPad ? 15 : 13
        subtitle.fontColor = UIColor.white.withAlphaComponent(0.78)
        subtitle.horizontalAlignmentMode = .left
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: title.position.x, y: topY - 32)
        header.addChild(subtitle)

        let score = makeGlassPill(text: "\(config.target.formatted())", icon: "scope", tint: kind.accent)
        score.position = CGPoint(x: size.width / 2 - 78, y: topY - 4)
        header.addChild(score)
    }

    private func drawBoard() {
        let mask = config.layout.mask
        let rows = config.rows
        let cols = config.cols
        let maxBoardWidth = min(size.width - (isPad ? 128 : 34), isPad ? size.width * 0.78 : size.width - 34)
        let availableHeight = size.height * (isPad ? 0.56 : 0.58)
        let tile = floor(min(maxBoardWidth / CGFloat(cols), availableHeight / CGFloat(rows)))
        let boardWidth = tile * CGFloat(cols)
        let boardHeight = tile * CGFloat(rows)
        let boardY = isPad ? size.height * 0.02 : size.height * 0.02

        let shadow = SKShapeNode(rectOf: CGSize(width: boardWidth + 34, height: boardHeight + 34), cornerRadius: 34)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: boardY - 10)
        shadow.zPosition = 8
        addChild(shadow)

        let board = SKShapeNode(rectOf: CGSize(width: boardWidth + 28, height: boardHeight + 28), cornerRadius: 30)
        board.fillColor = UIColor(white: 0.08, alpha: 0.58)
        board.strokeColor = UIColor.white.withAlphaComponent(0.24)
        board.lineWidth = 1.4
        board.glowWidth = 4
        board.position = CGPoint(x: 0, y: boardY)
        board.zPosition = 10
        addChild(board)

        let playable = playablePositions(rows: rows, cols: cols, mask: mask)
        let iceCount: Int = {
            if kind == .frostLocks || kind == .crown { return min(14, playable.count) }
            if kind == .fishHero { return 3 }
            return config.layout.iceCount
        }()
        // Fish-hero ice sits in the top corner so the seeker trails have a
        // visible target to chase.
        let ice: Set<Pos> = kind == .fishHero
            ? Set(playable.filter { $0.r <= 1 && $0.c >= cols - 2 }.prefix(iceCount))
            : Set(playable.prefix(iceCount))
        let locks = Set(playable.dropFirst(max(0, ice.count)).prefix(kind == .frostLocks || kind == .crown ? min(8, max(0, playable.count - ice.count)) : config.layout.lockCount))
        let bombs = Set(playable.reversed().prefix(kind == .bombStorm || kind == .crown ? 4 : config.layout.startingBombs))
        let rowStripe = Set(playable.filter { $0.r == rows / 2 }.prefix(4))
        let colStripe = Set(playable.filter { $0.c == cols / 2 }.suffix(4))
        // The marquee 2×2: same-colour square mid-board, fish hatching beside it.
        let squareAnchor = Pos(r: rows / 2, c: max(1, cols / 2 - 1))
        let square: Set<Pos> = kind == .fishHero ? [
            squareAnchor,
            Pos(r: squareAnchor.r, c: squareAnchor.c + 1),
            Pos(r: squareAnchor.r + 1, c: squareAnchor.c),
            Pos(r: squareAnchor.r + 1, c: squareAnchor.c + 1)
        ] : []
        let fishes: Set<Pos> = kind == .fishHero ? [
            Pos(r: squareAnchor.r - 1, c: squareAnchor.c + 2),
            Pos(r: squareAnchor.r - 2, c: squareAnchor.c + 3),
            Pos(r: squareAnchor.r + 2, c: squareAnchor.c - 1)
        ] : []

        let colors = Array(Theme.colors.prefix(config.colors))
        for r in 0..<rows {
            for c in 0..<cols {
                if let mask, !mask[r][c] { continue }

                let p = Pos(r: r, c: c)
                let node = makeTile(
                    color: square.contains(p) ? colors[0] : colors[(r * 2 + c * 3 + kind.level) % colors.count],
                    tile: tile,
                    special: fishes.contains(p) ? .fish : specialFor(pos: p, bombs: bombs, rowStripe: rowStripe, colStripe: colStripe),
                    blocker: blockerFor(pos: p, ice: ice, locks: locks)
                )
                if square.contains(p) {
                    let glow = SKShapeNode(rectOf: CGSize(width: tile * 0.94, height: tile * 0.94),
                                           cornerRadius: tile * 0.24)
                    glow.fillColor = .clear
                    glow.strokeColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.95)
                    glow.lineWidth = 3
                    glow.glowWidth = 8
                    glow.zPosition = 6
                    node.addChild(glow)
                }
                node.position = CGPoint(
                    x: -boardWidth / 2 + tile * (CGFloat(c) + 0.5),
                    y: boardHeight / 2 - tile * (CGFloat(r) + 0.5)
                )
                node.zPosition = 12 + CGFloat(r) * 0.01
                board.addChild(node)
            }
        }
    }

    private func drawActionOverlays() {
        let bannerY = isPad ? size.height * 0.31 : size.height * 0.25
        let banner = makeComboBanner(text: kind.comboText, color: kind.accent)
        banner.position = CGPoint(x: 0, y: bannerY)
        banner.zPosition = 100
        addChild(banner)

        switch kind {
        case .comboRush, .bombStorm, .crown, .lightning:
            drawBeams()
            drawScorePopups()
        case .frostLocks:
            drawIceCrackOverlay()
        case .boosters:
            drawBoosterRail()
        case .portal, .shapeWorlds:
            drawLevelChips()
        case .fishHero:
            drawFishTrails()
        case .dailyBoard:
            drawDailyChips()
        }
    }

    /// Dotted seeker arcs from the square-match zone toward the iced corner —
    /// sells "the fish hunts your goal" in a single still frame.
    private func drawFishTrails() {
        let start = CGPoint(x: -size.width * 0.10, y: -size.height * 0.04)
        let targets = [
            CGPoint(x: size.width * 0.30, y: size.height * 0.22),
            CGPoint(x: size.width * 0.24, y: size.height * 0.27),
            CGPoint(x: size.width * 0.34, y: size.height * 0.16)
        ]
        for (index, end) in targets.enumerated() {
            let path = CGMutablePath()
            path.move(to: start)
            let lift = CGFloat(60 + index * 26)
            let control = CGPoint(x: (start.x + end.x) / 2 - 40, y: max(start.y, end.y) + lift)
            path.addQuadCurve(to: end, control: control)

            let trail = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [10, 9]))
            trail.strokeColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.85)
            trail.lineWidth = 4
            trail.glowWidth = 6
            trail.lineCap = .round
            trail.zPosition = 96
            addChild(trail)

            let fish = SKShapeNode(ellipseOf: CGSize(width: 30, height: 19))
            fish.fillColor = UIColor(hex: "#22D3EE")
            fish.strokeColor = UIColor.white.withAlphaComponent(0.9)
            fish.lineWidth = 2
            fish.glowWidth = 5
            fish.position = CGPoint(x: (start.x + end.x) / 2, y: control.y - lift * 0.35)
            fish.zRotation = 0.5
            fish.zPosition = 97
            addChild(fish)
        }
    }

    /// "Same board for everyone" pills — kept clear of the wide banner text.
    private func drawDailyChips() {
        let y = size.height * 0.355
        let items: [(String, String)] = [
            (String(localized: "Everyone"), "globe"),
            ("#\(Levels.dailyChallenge().number)", "calendar"),
            (String(localized: "1 board"), "trophy.fill")
        ]
        for (i, item) in items.enumerated() {
            let chip = makeGlassPill(text: item.0, icon: item.1, tint: kind.accent)
            chip.position = CGPoint(x: CGFloat(i - 1) * (isPad ? 180 : 124), y: y)
            chip.zPosition = 104
            addChild(chip)
        }
    }

    private func drawFooter() {
        let footerY = -size.height / 2 + (isPad ? 90 : 68)
        let width = min(size.width - 34, isPad ? 620 : size.width - 34)
        let card = SKShapeNode(rectOf: CGSize(width: width, height: isPad ? 82 : 72), cornerRadius: 24)
        card.fillColor = UIColor.white.withAlphaComponent(0.22)
        card.strokeColor = UIColor.white.withAlphaComponent(0.32)
        card.lineWidth = 1
        card.position = CGPoint(x: 0, y: footerY)
        card.zPosition = 75
        addChild(card)

        let moves = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        moves.text = "\(max(7, config.moves - 4))"
        moves.fontSize = isPad ? 28 : 24
        moves.fontColor = .white
        moves.verticalAlignmentMode = .center
        moves.horizontalAlignmentMode = .center
        moves.position = CGPoint(x: -width / 2 + 60, y: 10)
        card.addChild(moves)

        let movesLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        movesLabel.text = String(localized: "Moves")
        movesLabel.fontSize = 11
        movesLabel.fontColor = UIColor.white.withAlphaComponent(0.72)
        movesLabel.verticalAlignmentMode = .center
        movesLabel.horizontalAlignmentMode = .center
        movesLabel.position = CGPoint(x: moves.position.x, y: -18)
        card.addChild(movesLabel)

        let progressTrack = SKShapeNode(rectOf: CGSize(width: width - 160, height: 12), cornerRadius: 6)
        progressTrack.fillColor = UIColor.black.withAlphaComponent(0.20)
        progressTrack.strokeColor = .clear
        progressTrack.position = CGPoint(x: 40, y: 4)
        card.addChild(progressTrack)

        let progress = SKShapeNode(rectOf: CGSize(width: (width - 160) * 0.72, height: 12), cornerRadius: 6)
        progress.fillColor = kind.accent
        progress.strokeColor = .clear
        progress.position = CGPoint(x: 40 - (width - 160) * 0.14, y: 4)
        progress.glowWidth = 4
        card.addChild(progress)

        let score = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        score.text = "\(Int(Double(config.target) * 0.72).formatted())"
        score.fontSize = 13
        score.fontColor = .white
        score.verticalAlignmentMode = .center
        score.horizontalAlignmentMode = .right
        score.position = CGPoint(x: width / 2 - 22, y: 4)
        card.addChild(score)
    }

    private var isPad: Bool {
        size.width >= 700
    }

    private func playablePositions(rows: Int, cols: Int, mask: [[Bool]]?) -> [Pos] {
        var out: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols where mask?[r][c] ?? true {
                out.append(Pos(r: r, c: c))
            }
        }
        return out.sorted { lhs, rhs in
            let dl = abs(lhs.r - rows / 2) + abs(lhs.c - cols / 2)
            let dr = abs(rhs.r - rows / 2) + abs(rhs.c - cols / 2)
            if dl == dr { return lhs.r == rhs.r ? lhs.c < rhs.c : lhs.r < rhs.r }
            return dl < dr
        }
    }

    private func specialFor(pos: Pos, bombs: Set<Pos>, rowStripe: Set<Pos>, colStripe: Set<Pos>) -> Special? {
        if bombs.contains(pos) { return .bomb }
        if kind == .comboRush && rowStripe.contains(pos) { return .stripedRow }
        if kind == .lightning && colStripe.contains(pos) { return .stripedCol }
        if kind == .boosters && pos.r == config.rows / 2 && pos.c == config.cols / 2 { return .colorBomb }
        if kind == .crown && (pos.r + pos.c).isMultiple(of: 9) { return .wrapped }
        return nil
    }

    private func blockerFor(pos: Pos, ice: Set<Pos>, locks: Set<Pos>) -> Blocker? {
        if locks.contains(pos) { return Blocker(type: .lock, hits: 1) }
        if ice.contains(pos) { return Blocker(type: .ice, hits: 2) }
        return nil
    }

    private func makeTile(color: String, tile: CGFloat, special: Special?, blocker: Blocker?) -> SKNode {
        let container = SKNode()

        let back = SKShapeNode(rectOf: CGSize(width: tile * 0.88, height: tile * 0.88), cornerRadius: tile * 0.22)
        back.fillColor = UIColor.white.withAlphaComponent(0.20)
        back.strokeColor = UIColor.white.withAlphaComponent(0.20)
        back.lineWidth = 1
        container.addChild(back)

        let fruit = SKSpriteNode(texture: Theme.emojiTexture(forColor: color))
        fruit.size = CGSize(width: tile * 0.62, height: tile * 0.62)
        fruit.zPosition = 2
        fruit.alpha = blocker == nil ? 1 : 0.48
        container.addChild(fruit)

        if let special {
            drawSpecial(special, tile: tile, on: container)
        }

        if let blocker {
            switch blocker.type {
            case .ice:
                let ice = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                ice.fillColor = UIColor(hex: "#7DD3FC").withAlphaComponent(0.35)
                ice.strokeColor = UIColor(hex: "#E0F2FE").withAlphaComponent(0.88)
                ice.lineWidth = 2
                ice.glowWidth = 2
                ice.zPosition = 5
                container.addChild(ice)
            case .lock:
                let scrim = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                scrim.fillColor = UIColor.black.withAlphaComponent(0.44)
                scrim.strokeColor = UIColor.white.withAlphaComponent(0.18)
                scrim.lineWidth = 1
                scrim.zPosition = 5
                container.addChild(scrim)

                let lock = Icons.sprite("lock.fill", size: tile * 0.30, tint: .white)
                lock.zPosition = 6
                container.addChild(lock)
            case .jelly:
                let jelly = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.24)
                jelly.fillColor = UIColor(hex: "#F9A8D4").withAlphaComponent(0.36)
                jelly.strokeColor = UIColor(hex: "#EC4899").withAlphaComponent(0.8)
                jelly.lineWidth = 2
                jelly.zPosition = 5
                container.addChild(jelly)
            case .crate:
                let crate = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.12)
                crate.fillColor = UIColor(hex: "#92400E").withAlphaComponent(0.58)
                crate.strokeColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.86)
                crate.lineWidth = 2
                crate.zPosition = 5
                container.addChild(crate)
            case .colorLock:
                let ring = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                ring.fillColor = UIColor.black.withAlphaComponent(0.30)
                ring.strokeColor = UIColor(hex: blocker.requiredColor ?? color).withAlphaComponent(0.95)
                ring.lineWidth = 3
                ring.zPosition = 5
                container.addChild(ring)
            case .chest:
                let chest = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.16)
                chest.fillColor = UIColor(hex: "#92400E").withAlphaComponent(0.76)
                chest.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.95)
                chest.lineWidth = 2
                chest.zPosition = 5
                container.addChild(chest)
            case .vine:
                let vine = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                vine.fillColor = UIColor(hex: "#064E3B").withAlphaComponent(0.28)
                vine.strokeColor = UIColor(hex: "#22C55E").withAlphaComponent(0.95)
                vine.lineWidth = 2
                vine.zPosition = 5
                container.addChild(vine)
            case .chocolate:
                let cocoa = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                cocoa.fillColor = UIColor(hex: "#3B1F0E").withAlphaComponent(0.92)
                cocoa.strokeColor = UIColor(hex: "#7C3A12").withAlphaComponent(0.95)
                cocoa.lineWidth = 2
                cocoa.zPosition = 5
                container.addChild(cocoa)
            case .syrup:
                let goo = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                goo.fillColor = UIColor(hex: "#EC4899").withAlphaComponent(0.50)
                goo.strokeColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.85)
                goo.lineWidth = 2
                goo.zPosition = 5
                container.addChild(goo)
            case .countdown:
                let fuse = SKShapeNode(rectOf: CGSize(width: tile * 0.84, height: tile * 0.84), cornerRadius: tile * 0.18)
                fuse.fillColor = UIColor(hex: "#7F1D1D").withAlphaComponent(0.30)
                fuse.strokeColor = UIColor(hex: "#EF4444").withAlphaComponent(0.95)
                fuse.lineWidth = 2
                fuse.zPosition = 5
                container.addChild(fuse)
            }
        }

        return container
    }

    private func drawSpecial(_ special: Special, tile: CGFloat, on node: SKNode) {
        switch special {
        case .stripedRow, .stripedCol:
            let stripe = SKShapeNode(rectOf: CGSize(width: special == .stripedRow ? tile * 0.78 : tile * 0.18,
                                                    height: special == .stripedRow ? tile * 0.18 : tile * 0.78),
                                     cornerRadius: tile * 0.09)
            stripe.fillColor = UIColor.white.withAlphaComponent(0.86)
            stripe.strokeColor = UIColor.white.withAlphaComponent(0.5)
            stripe.zPosition = 4
            node.addChild(stripe)
        case .wrapped:
            let wrap = SKShapeNode(rectOf: CGSize(width: tile * 0.74, height: tile * 0.74), cornerRadius: tile * 0.18)
            wrap.fillColor = .clear
            wrap.strokeColor = UIColor.white.withAlphaComponent(0.88)
            wrap.lineWidth = 3
            wrap.zPosition = 4
            node.addChild(wrap)
        case .colorBomb:
            let bomb = SKShapeNode(circleOfRadius: tile * 0.26)
            bomb.fillColor = UIColor.black.withAlphaComponent(0.92)
            bomb.strokeColor = UIColor.white.withAlphaComponent(0.85)
            bomb.lineWidth = 2
            bomb.glowWidth = 6
            bomb.zPosition = 4
            node.addChild(bomb)
            for i in 0..<6 {
                let dot = SKShapeNode(circleOfRadius: tile * 0.035)
                dot.fillColor = UIColor(hex: Theme.colors[i % Theme.colors.count])
                dot.strokeColor = .clear
                dot.position = CGPoint(x: cos(CGFloat(i) * .pi / 3) * tile * 0.18,
                                       y: sin(CGFloat(i) * .pi / 3) * tile * 0.18)
                dot.zPosition = 5
                node.addChild(dot)
            }
        case .bomb:
            let bomb = SKShapeNode(circleOfRadius: tile * 0.26)
            bomb.fillColor = UIColor(hex: "#111827")
            bomb.strokeColor = UIColor.white.withAlphaComponent(0.85)
            bomb.lineWidth = 2
            bomb.glowWidth = 5
            bomb.zPosition = 4
            node.addChild(bomb)

            let spark = SKShapeNode(circleOfRadius: tile * 0.06)
            spark.fillColor = UIColor(hex: "#FACC15")
            spark.strokeColor = .clear
            spark.glowWidth = 7
            spark.position = CGPoint(x: tile * 0.18, y: tile * 0.20)
            spark.zPosition = 5
            node.addChild(spark)
        case .fish:
            let body = SKShapeNode(ellipseOf: CGSize(width: tile * 0.5, height: tile * 0.32))
            body.fillColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.9)
            body.strokeColor = UIColor.white.withAlphaComponent(0.85)
            body.lineWidth = 2
            body.zPosition = 4
            node.addChild(body)
        }
    }

    private func makeComboBanner(text: String, color: UIColor) -> SKNode {
        let container = SKNode()

        let halo = SKShapeNode(circleOfRadius: isPad ? 110 : 92)
        halo.fillColor = color.withAlphaComponent(0.22)
        halo.strokeColor = .clear
        halo.glowWidth = isPad ? 28 : 22
        halo.blendMode = .add
        container.addChild(halo)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = isPad ? 64 : 48
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        container.addChild(label)

        let colorLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        colorLabel.text = text
        colorLabel.fontSize = label.fontSize
        colorLabel.fontColor = color
        colorLabel.horizontalAlignmentMode = .center
        colorLabel.verticalAlignmentMode = .center
        colorLabel.position = CGPoint(x: 0, y: -4)
        colorLabel.zPosition = -1
        container.addChild(colorLabel)

        return container
    }

    private func drawBeams() {
        for angle in stride(from: CGFloat(0), to: .pi * 2, by: .pi / 4) {
            let beam = SKShapeNode(rectOf: CGSize(width: 9, height: size.height * 0.56), cornerRadius: 4)
            beam.fillColor = kind.accent.withAlphaComponent(0.45)
            beam.strokeColor = .clear
            beam.glowWidth = 10
            beam.zRotation = angle
            beam.position = CGPoint(x: 0, y: isPad ? size.height * 0.02 : size.height * 0.02)
            beam.zPosition = 55
            beam.blendMode = .add
            addChild(beam)
        }
    }

    private func drawScorePopups() {
        let values = ["+1,800", "+3,200", "+8,400"]
        for (i, value) in values.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = value
            label.fontSize = isPad ? 24 : 20
            label.fontColor = UIColor.white.withAlphaComponent(0.92)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: CGFloat(i - 1) * size.width * 0.22, y: size.height * CGFloat(0.11 + Double(i) * 0.05))
            label.zPosition = 95
            addChild(label)
        }
    }

    private func drawIceCrackOverlay() {
        let crack = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size.width * 0.22, y: size.height * 0.10))
        path.addLine(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.02))
        path.addLine(to: CGPoint(x: size.width * 0.04, y: size.height * 0.08))
        path.addLine(to: CGPoint(x: size.width * 0.20, y: -size.height * 0.02))
        crack.path = path
        crack.strokeColor = UIColor.white.withAlphaComponent(0.88)
        crack.lineWidth = 4
        crack.glowWidth = 8
        crack.zPosition = 96
        addChild(crack)
    }

    private func drawBoosterRail() {
        let y = size.height * 0.26
        let symbols = [("hammer.fill", "#F97316"), ("shuffle", "#22D3EE"), ("hand.raised.fill", "#A78BFA")]
        for (i, item) in symbols.enumerated() {
            let node = makeGlassPill(text: i == 0 ? String(localized: "Hammer") : i == 1 ? String(localized: "Shuffle") : String(localized: "Swap"), icon: item.0, tint: UIColor(hex: item.1))
            node.position = CGPoint(x: CGFloat(i - 1) * (isPad ? 170 : 118), y: y)
            node.zPosition = 104
            addChild(node)
        }
    }

    private func drawLevelChips() {
        let y = size.height * 0.27
        for (i, level) in [7, 25, 50, 100].enumerated() {
            let chip = makeGlassPill(text: "L\(level)", icon: "map.fill", tint: kind.accent)
            chip.position = CGPoint(x: CGFloat(i) * (isPad ? 116 : 82) - (isPad ? 174 : 123), y: y)
            chip.zPosition = 104
            addChild(chip)
        }
    }

    private func makeGlassPill(text: String, icon: String, tint: UIColor) -> SKNode {
        let node = SKNode()
        let width = max(CGFloat(text.count) * 11 + 58, 74)
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 36), cornerRadius: 18)
        bg.fillColor = UIColor.white.withAlphaComponent(0.22)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.32)
        bg.lineWidth = 1
        node.addChild(bg)

        let image = Icons.sprite(icon, size: 14, tint: tint)
        image.position = CGPoint(x: -width / 2 + 19, y: 0)
        image.zPosition = 1
        node.addChild(image)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 13
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width / 2 + 36, y: 0)
        label.zPosition = 1
        node.addChild(label)
        return node
    }
}
#endif
