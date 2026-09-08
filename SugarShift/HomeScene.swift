import SpriteKit
import UIKit

/// Static landing/home page: brand logo, tagline, big PLAY button, grass strip
/// at the bottom with fruits and bombs scattered like Candy Crush's home decor —
/// matched to our app's fruit/bomb gameplay vocabulary.
final class HomeScene: SKScene {

    var onPlay: (() -> Void)?
    var onOpeningFinished: (() -> Void)?

    private let fruits = ["🍊", "🍇", "🫐", "🍏", "🍌", "🍒", "🍓", "🥭"]

    private var hasSetup = false
    private var settingsCard: SettingsCard?
    private var storyCard: StorySceneCard?
    private var enteringCampaign = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        if size.width > 100 { setupOnce() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if !hasSetup, size.width > 100 { setupOnce() }
    }

    private func setupOnce() {
        hasSetup = true
        buildBokeh()
        buildClouds()
        buildGrass()
        buildSpriteDecorations()
        buildLogo()
        buildPlayButton()
        buildSettingsButton()
        buildStoryReplayButton()
        buildAmbientSparkles()
    }

    // MARK: - Background atmosphere

    private func buildBokeh() {
        let palette = [
            UIColor(hex: "#FBCFE8").withAlphaComponent(0.40),  // pink
            UIColor(hex: "#A7F3D0").withAlphaComponent(0.40),  // mint
            UIColor(hex: "#FED7AA").withAlphaComponent(0.36),  // peach
            UIColor(hex: "#DDD6FE").withAlphaComponent(0.36)   // lavender
        ]
        for _ in 0..<7 {
            let radius = CGFloat.random(in: 70...140)
            let orb = SKShapeNode(circleOfRadius: radius)
            orb.fillColor = palette.randomElement()!
            orb.strokeColor = .clear
            orb.glowWidth = 18
            orb.blendMode = .add
            orb.zPosition = -10
            orb.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 ... size.width / 2),
                y: CGFloat.random(in: 0 ... size.height / 2)
            )
            addChild(orb)

            let dur = TimeInterval.random(in: 9...14)
            let dx = CGFloat.random(in: -40...40)
            let dy = CGFloat.random(in: 60...140)
            orb.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: dur),
                    .scale(to: 1.15, duration: dur),
                    .fadeAlpha(to: 0.55, duration: dur)
                ]),
                .group([
                    .moveBy(x: -dx, y: -dy, duration: dur),
                    .scale(to: 1.0, duration: dur),
                    .fadeAlpha(to: 0.36, duration: dur)
                ])
            ])))
        }
    }

    private func buildClouds() {
        let topZone = size.height * 0.15
        for _ in 0..<3 {
            let cloud = makeCloud()
            cloud.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 40 ... size.width / 2 - 40),
                y: CGFloat.random(in: topZone ... size.height / 2 - 80)
            )
            cloud.zPosition = -5
            cloud.alpha = 0.85
            addChild(cloud)

            let dist: CGFloat = 30
            let dur = TimeInterval.random(in: 8...12)
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: dist, y: 0, duration: dur),
                .moveBy(x: -dist, y: 0, duration: dur)
            ])))
        }
    }

    private func buildAmbientSparkles() {
        let action = SKAction.run { [weak self] in self?.emitSparkle() }
        run(.repeatForever(.sequence([
            action,
            .wait(forDuration: 0.32, withRange: 0.18)
        ])))
    }

    private func emitSparkle() {
        let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...2.4))
        dot.fillColor = .white
        dot.strokeColor = .clear
        dot.glowWidth = 4
        dot.blendMode = .add
        dot.zPosition = 30
        dot.position = CGPoint(
            x: CGFloat.random(in: -size.width / 2 ... size.width / 2),
            y: CGFloat.random(in: -size.height * 0.1 ... size.height / 2)
        )
        dot.alpha = 0
        dot.setScale(0.4)
        addChild(dot)

        let life = TimeInterval.random(in: 1.2...2.0)
        dot.run(.sequence([
            .group([
                .scale(to: 1.4, duration: life * 0.4),
                .fadeAlpha(to: 1.0, duration: life * 0.3)
            ]),
            .group([
                .scale(to: 0.2, duration: life * 0.6),
                .fadeOut(withDuration: life * 0.6)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Grass

    private func buildGrass() {
        // Soft mint mound rising up from the bottom.
        let grassH: CGFloat = 240
        let mound = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.6,
                                                   height: grassH * 1.7))
        mound.fillColor = UIColor(hex: "#A7F3D0")
        mound.strokeColor = .clear
        mound.position = CGPoint(x: 0, y: -size.height / 2 - grassH * 0.55)
        mound.zPosition = 5
        addChild(mound)

        // Brighter rim along the top of the mound to give the "horizon" line.
        let rim = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.6,
                                                 height: grassH * 1.7 + 8))
        rim.fillColor = .clear
        rim.strokeColor = UIColor(hex: "#86EFAC").withAlphaComponent(0.7)
        rim.lineWidth = 4
        rim.position = mound.position
        rim.zPosition = 5
        addChild(rim)

        // Daisies + grass tufts scattered on the green
        let mountainTop = mound.position.y + (grassH * 1.7 / 2)
        for _ in 0..<22 {
            let tuft = makeGrassTuft()
            tuft.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 16 ... size.width / 2 - 16),
                y: CGFloat.random(in: -size.height / 2 + 8 ... mountainTop - 12)
            )
            tuft.zPosition = 7
            addChild(tuft)
        }

        for _ in 0..<8 {
            let daisy = makeDaisy()
            daisy.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 24 ... size.width / 2 - 24),
                y: CGFloat.random(in: -size.height / 2 + 24 ... mountainTop - 24)
            )
            daisy.zPosition = 8
            addChild(daisy)
        }
    }

    /// Fruits and bombs sat on the grass like Candy Crush's home decor.
    private func buildSpriteDecorations() {
        // Two rows of decorations: a back row (smaller, further from camera)
        // and a front row (bigger, sitting at the bottom).
        let baseY = -size.height / 2 + 90

        struct Item { let type: String; let scale: CGFloat; let xRel: CGFloat; let yRel: CGFloat }
        let items: [Item] = [
            // Front row — bigger, lower
            .init(type: "🍊",   scale: 1.05, xRel: -0.40, yRel: 0.00),
            .init(type: "bomb", scale: 0.95, xRel: -0.22, yRel: -0.08),
            .init(type: "🍇",   scale: 1.10, xRel:  0.02, yRel: 0.05),
            .init(type: "🍒",   scale: 0.95, xRel:  0.22, yRel: -0.04),
            .init(type: "bomb", scale: 1.00, xRel:  0.42, yRel: 0.02),
            // Back row — smaller, further behind
            .init(type: "🫐",   scale: 0.80, xRel: -0.34, yRel: 0.42),
            .init(type: "🍏",   scale: 0.78, xRel: -0.10, yRel: 0.52),
            .init(type: "🍓",   scale: 0.84, xRel:  0.16, yRel: 0.46),
            .init(type: "🥭",   scale: 0.80, xRel:  0.36, yRel: 0.48)
        ]

        for item in items {
            let isBack = item.yRel > 0.2
            let baseSize: CGFloat = isBack ? 52 : 64
            let x = item.xRel * size.width
            let y = baseY + item.yRel * 180

            let node: SKNode
            if item.type == "bomb" {
                node = makeBomb(size: baseSize * 0.95)
            } else {
                let tex = Theme.emojiTexture(item.type)
                let sprite = SKSpriteNode(texture: tex)
                sprite.size = CGSize(width: baseSize, height: baseSize)
                node = sprite
            }
            node.setScale(item.scale)
            node.position = CGPoint(x: x, y: y)
            node.zPosition = isBack ? 9 : 11
            node.zRotation = CGFloat.random(in: -0.18...0.18)
            addChild(node)

            // Soft drop shadow ellipse below the item
            let shadow = SKShapeNode(ellipseOf: CGSize(width: baseSize * 0.7,
                                                       height: baseSize * 0.18))
            shadow.fillColor = UIColor(white: 0, alpha: 0.18)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: x, y: y - baseSize * 0.45)
            shadow.zPosition = node.zPosition - 0.5
            addChild(shadow)

            // Subtle bob
            let bobAmt = CGFloat.random(in: 3...6)
            let dur = TimeInterval.random(in: 1.6...2.6)
            node.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: bobAmt, duration: dur),
                .moveBy(x: 0, y: -bobAmt, duration: dur)
            ])))
            shadow.run(.repeatForever(.sequence([
                .scale(to: 0.92, duration: dur),
                .scale(to: 1.0, duration: dur)
            ])))
        }
    }

    // MARK: - Logo + buttons

    private func buildLogo() {
        let logo = BrandLogo.make(fontSize: 64, withTagline: true)
        logo.position = CGPoint(x: 0, y: size.height * 0.20)
        logo.zPosition = 50
        logo.alpha = 0
        logo.setScale(0.6)
        addChild(logo)
        logo.run(.group([
            .fadeIn(withDuration: 0.4),
            .sequence([.scale(to: 1.06, duration: 0.5),
                       .scale(to: 1.0,  duration: 0.18)])
        ]))
    }

    private func buildPlayButton() {
        let btnW: CGFloat = 220
        let btnH: CGFloat = 64
        let centerY = -size.height * 0.04

        // Soft shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH),
                                  cornerRadius: btnH / 2)
        shadow.fillColor = UIColor(white: 0, alpha: 0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: centerY - 6)
        shadow.zPosition = 49
        addChild(shadow)

        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH),
                               cornerRadius: btnH / 2)
        btn.fillColor = UIColor(hex: "#F472B6")
        btn.strokeColor = .white
        btn.lineWidth = 3
        btn.position = CGPoint(x: 0, y: centerY)
        btn.name = "playBtn"
        btn.zPosition = 50
        addChild(btn)

        // Top bevel highlight
        let bevel = SKShapeNode(rectOf: CGSize(width: btnW * 0.85, height: 8),
                                 cornerRadius: 4)
        bevel.fillColor = UIColor.white.withAlphaComponent(0.55)
        bevel.strokeColor = .clear
        bevel.position = CGPoint(x: 0, y: btnH / 2 - 14)
        bevel.zPosition = 1
        btn.addChild(bevel)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = String(localized: "PLAY")
        label.fontSize = 28
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        btn.addChild(label)

        btn.isAccessibilityElement = true
        btn.accessibilityLabel = String(localized: "Play")
        btn.accessibilityTraits = .button

        // Spark icons either side of the label
        for sx in [-1.0, 1.0] as [CGFloat] {
            let spark = SKLabelNode(text: "✦")
            spark.fontName = "AvenirNext-Heavy"
            spark.fontSize = 18
            spark.fontColor = UIColor(hex: "#FFFBEB")
            spark.alpha = 0.9
            spark.verticalAlignmentMode = .center
            spark.horizontalAlignmentMode = .center
            spark.position = CGPoint(x: sx * 56, y: 1)
            spark.zPosition = 2
            btn.addChild(spark)
            spark.run(.repeatForever(.sequence([
                .group([.scale(to: 1.25, duration: 0.7), .fadeAlpha(to: 1.0, duration: 0.7)]),
                .group([.scale(to: 0.85, duration: 0.7), .fadeAlpha(to: 0.6, duration: 0.7)])
            ])))
        }

        // Gentle pulse so the user's eye lands on it
        btn.run(.repeatForever(.sequence([
            .scale(to: 1.04, duration: 1.0),
            .scale(to: 1.0,  duration: 1.0)
        ])))
    }

    private func buildSettingsButton() {
        let gear = SKShapeNode(circleOfRadius: 22)
        gear.fillColor = UIColor.white.withAlphaComponent(0.9)
        gear.strokeColor = UIColor(hex: "#FBCFE8")
        gear.lineWidth = 2
        gear.position = CGPoint(x: size.width / 2 - 36,
                                 y: size.height / 2 - 60)
        gear.zPosition = 50
        gear.name = "settingsBtn"
        addChild(gear)

        let icon = Icons.sprite(Icons.Name.settings, size: 20,
                                tint: UIColor(hex: "#EC4899"))
        gear.addChild(icon)
        gear.isAccessibilityElement = true
        gear.accessibilityLabel = String(localized: "Settings")
        gear.accessibilityTraits = .button
    }

    private func buildStoryReplayButton() {
        let button = HomeStoryButton(rectOf: CGSize(width: 164, height: 44), cornerRadius: 22)
        button.name = "storyReplay"
        button.zPosition = 51
        button.position = CGPoint(x: 0, y: (childNode(withName: "playBtn")?.position.y ?? 0) - 82)
        MenuStyle.decorate(button, size: CGSize(width: 164, height: 44), tone: .cream)
        button.addChild(GameSurface.label(String(localized: "The memory box"), size: 15, color: MenuStyle.ink))
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.accessibilityLabel = String(localized: "Replay the opening story")
        button.onActivate = { [weak self] in
            guard let self, self.settingsCard == nil, !self.enteringCampaign, self.storyCard == nil else { return }
            self.presentStory(StoryStore.shared.replayOpening(), entersCampaign: false)
        }
        addChild(button)
    }

    private func beginCampaignWithStory() {
        guard storyCard == nil else { return }
        if let opening = StoryStore.shared.openingPresentation(
            highestUnlockedLevel: Persistence.highestUnlockedLevel,
            hasCompletedAnyLevel: CampaignProgress.isCompleted(level: 1)) {
            presentStory(opening, entersCampaign: true)
        } else {
            enteringCampaign = false
            onPlay?()
        }
    }

    private func presentStory(_ presentation: StoryPresentation, entersCampaign: Bool) {
        guard storyCard == nil else { return }
        let card = StorySceneCard(presentation: presentation, sceneSize: size,
                                  safeAreaInsets: view?.safeAreaInsets ?? .zero)
        storyCard = card
        addChild(card)
        card.onComplete = { [weak self] in
            guard let self else { return }
            self.storyCard = nil
            self.enteringCampaign = false
            if entersCampaign { (self.onOpeningFinished ?? self.onPlay)?() }
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let card = settingsCard else { return }
        _ = card.handleTouchBegan(at: t.location(in: self), timestamp: t.timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let card = settingsCard else { return }
        _ = card.handleTouchMoved(at: t.location(in: self), timestamp: t.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        if let storyCard {
            storyCard.handleTap(at: p)
            return
        }
        guard !enteringCampaign else { return }
        // If the settings card is up, it consumes taps first.
        if let card = settingsCard {
            _ = card.handleTouchEnded(at: p, timestamp: t.timestamp)
            return
        }

        var n: SKNode? = atPoint(p)
        while let cur = n {
            if cur.name == "playBtn" {
                bounce(cur)
                run(.sequence([.wait(forDuration: 0.16),
                               .run { [weak self] in self?.beginCampaignWithStory() }]))
                enteringCampaign = true
                return
            }
            if cur.name == "storyReplay" {
                presentStory(StoryStore.shared.replayOpening(), entersCampaign: false)
                return
            }
            if cur.name == "settingsBtn" {
                bounce(cur)
                openSettings()
                return
            }
            n = cur.parent
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        settingsCard?.handleTouchCancelled()
    }

    private func openSettings() {
        settingsCard?.dismiss()
        let card = SettingsCard(sceneSize: size)
        card.position = .zero
        addChild(card)
        settingsCard = card

        card.onAction = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .close, .restartLevel:
                self.settingsCard?.dismiss()
                self.settingsCard = nil
            case .resetProgress:
                self.settingsCard?.dismiss { [weak self] in
                    self?.settingsCard = nil
                    Persistence.resetAll()
                }
            case .firebaseSignIn:
                self.signInToFirebaseFromSettings()
            case .firebaseSync:
                self.syncFirebaseFromSettings()
            case .firebaseSignOut:
                FirebaseBackendService.shared.signOut()
                self.reopenSettingsAfterFirebaseAction()
            case .shapedBoardChanged:
                break
            case .visualAccessibilityChanged:
                break
            case .gameplayAppearanceChanged:
                break
            case .showCombos:
                break
            }
        }
    }

    private func signInToFirebaseFromSettings() {
        FirebaseBackendService.shared.signInWithApple(presentationAnchor: view?.window) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Effects.notify(.success)
                case .failure:
                    Effects.notify(.warning)
                }
                self?.reopenSettingsAfterFirebaseAction()
            }
        }
    }

    private func syncFirebaseFromSettings() {
        FirebaseBackendService.shared.syncNow { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Effects.notify(.success)
                case .failure:
                    Effects.notify(.warning)
                }
                self?.reopenSettingsAfterFirebaseAction()
            }
        }
    }

    private func reopenSettingsAfterFirebaseAction() {
        settingsCard?.dismiss { [weak self] in
            guard let self else { return }
            self.settingsCard = nil
            self.openSettings()
        }
    }

    private func bounce(_ node: SKNode) {
        node.run(.sequence([
            .scale(to: 0.94, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }

    // MARK: - Decoration factories

    private func makeCloud() -> SKNode {
        let node = SKNode()
        let radii: [CGFloat] = [22, 28, 22, 18]
        var x: CGFloat = -30
        for r in radii {
            let c = SKShapeNode(circleOfRadius: r)
            c.fillColor = UIColor.white.withAlphaComponent(0.92)
            c.strokeColor = .clear
            c.position = CGPoint(x: x, y: CGFloat.random(in: -3...3))
            node.addChild(c)
            x += r * 0.9
        }
        return node
    }

    private func makeGrassTuft() -> SKNode {
        let node = SKNode()
        let blades = 3
        for i in 0..<blades {
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

    private func makeDaisy() -> SKNode {
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
        return node
    }

    /// Cute cartoon bomb — black sphere, brown fuse, yellow spark with looping flicker.
    private func makeBomb(size: CGFloat) -> SKNode {
        let node = SKNode()

        // Base shadow under the bomb
        let baseShadow = SKShapeNode(ellipseOf: CGSize(width: size * 0.75,
                                                        height: size * 0.18))
        baseShadow.fillColor = UIColor(white: 0, alpha: 0.18)
        baseShadow.strokeColor = .clear
        baseShadow.position = CGPoint(x: 0, y: -size * 0.5)
        baseShadow.zPosition = 0
        node.addChild(baseShadow)

        // Main body — radial-gradient look via overlapping circles
        let body = SKShapeNode(circleOfRadius: size / 2)
        body.fillColor = UIColor(hex: "#1F2937")
        body.strokeColor = UIColor(hex: "#374151")
        body.lineWidth = 2
        body.zPosition = 1
        node.addChild(body)

        // Lighter inner ring for sphere illusion
        let inner = SKShapeNode(circleOfRadius: size / 2 - 6)
        inner.fillColor = UIColor(hex: "#374151")
        inner.strokeColor = .clear
        inner.zPosition = 2
        inner.alpha = 0.6
        node.addChild(inner)

        // White shine on top-left
        let shine = SKShapeNode(ellipseOf: CGSize(width: size * 0.35,
                                                   height: size * 0.18))
        shine.fillColor = UIColor.white.withAlphaComponent(0.45)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -size * 0.16, y: size * 0.18)
        shine.zPosition = 3
        node.addChild(shine)

        // Tiny dot accent
        let dot = SKShapeNode(circleOfRadius: size * 0.05)
        dot.fillColor = UIColor.white.withAlphaComponent(0.7)
        dot.strokeColor = .clear
        dot.position = CGPoint(x: size * 0.20, y: size * 0.22)
        dot.zPosition = 4
        node.addChild(dot)

        // Fuse cap (small bronze nub on top)
        let cap = SKShapeNode(rectOf: CGSize(width: size * 0.20, height: size * 0.10),
                               cornerRadius: 2)
        cap.fillColor = UIColor(hex: "#92400E")
        cap.strokeColor = UIColor(hex: "#78350F")
        cap.lineWidth = 1
        cap.position = CGPoint(x: 0, y: size * 0.54)
        cap.zPosition = 5
        node.addChild(cap)

        // Curly fuse line
        let fusePath = UIBezierPath()
        fusePath.move(to: CGPoint(x: 0, y: size * 0.6))
        fusePath.addCurve(to: CGPoint(x: size * 0.18, y: size * 0.92),
                          controlPoint1: CGPoint(x: size * 0.10, y: size * 0.66),
                          controlPoint2: CGPoint(x: -size * 0.06, y: size * 0.84))
        let fuse = SKShapeNode(path: fusePath.cgPath)
        fuse.strokeColor = UIColor(hex: "#B45309")
        fuse.lineWidth = 3
        fuse.lineCap = .round
        fuse.fillColor = .clear
        fuse.zPosition = 6
        node.addChild(fuse)

        // Spark at end of fuse
        let spark = SKLabelNode(text: "✦")
        spark.fontName = "AvenirNext-Heavy"
        spark.fontSize = size * 0.4
        spark.fontColor = UIColor(hex: "#FBBF24")
        spark.verticalAlignmentMode = .center
        spark.horizontalAlignmentMode = .center
        spark.position = CGPoint(x: size * 0.18, y: size * 0.92)
        spark.zPosition = 7
        node.addChild(spark)
        spark.run(.repeatForever(.sequence([
            .group([.scale(to: 1.4, duration: 0.30),
                    .fadeAlpha(to: 1.0, duration: 0.30)]),
            .group([.scale(to: 0.7, duration: 0.30),
                    .fadeAlpha(to: 0.5, duration: 0.30)])
        ])))

        // Soft glow halo around the spark
        let halo = SKShapeNode(circleOfRadius: size * 0.28)
        halo.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.55)
        halo.strokeColor = .clear
        halo.glowWidth = 6
        halo.blendMode = .add
        halo.position = CGPoint(x: size * 0.18, y: size * 0.92)
        halo.zPosition = 6.5
        node.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.2, duration: 0.35),
                    .fadeAlpha(to: 0.85, duration: 0.35)]),
            .group([.scale(to: 0.9, duration: 0.35),
                    .fadeAlpha(to: 0.4, duration: 0.35)])
        ])))

        return node
    }
}

private final class HomeStoryButton: SKShapeNode {
    var onActivate: (() -> Void)?
    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
