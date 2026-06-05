import SpriteKit
import UIKit

/// Dreamy splash scene: drifting bokeh orbs, fruits gently falling and puffing into
/// soft clouds on the ground line, ambient sparkles, and a halo'd brand logo.
final class SplashScene: SKScene {

    // Called when the scene's intro animation has had enough time to play
    var onReady: (() -> Void)?

    private let fruits = ["🍊", "🍇", "🫐", "🍏", "🍌", "🍒", "🍓", "🥭"]
    private var groundY: CGFloat = 0
    private var hasSetup = false

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Wait for a real size — viewDidLoad's bounds are sometimes still .zero,
        // which breaks the random-range math below.
        if size.width > 100 { setupOnce() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if !hasSetup, size.width > 100 { setupOnce() }
    }

    private func setupOnce() {
        hasSetup = true
        // Ground = top of grass mound where falling fruits land and puff.
        groundY = -size.height * 0.32

        spawnBokeh()
        buildGrass()
        spawnAmbientSparkles()
        startFruitSpawner()
        startBombSpawner()
        revealLogo()
        buildLoadingDots()

        run(.sequence([
            .wait(forDuration: 3.4),
            .run { [weak self] in self?.onReady?() }
        ]))
    }

    // MARK: - Logo

    private func revealLogo() {
        let logo = BrandLogo.make(fontSize: 60, withTagline: true)
        // Sit the logo in the upper third of the screen so the fruits below
        // get room to fall and puff.
        logo.position = CGPoint(x: 0, y: size.height * 0.18)
        logo.zPosition = 100
        logo.alpha = 0
        logo.setScale(0.4)
        // Slight upward drift on entry for a more dramatic reveal.
        logo.run(.sequence([
            .wait(forDuration: 0.3),
            .group([
                .fadeIn(withDuration: 0.55),
                .sequence([
                    .scale(to: 1.08, duration: 0.55),
                    .scale(to: 1.0, duration: 0.22)
                ]),
                .moveBy(x: 0, y: 14, duration: 0.7)
            ])
        ]))
        addChild(logo)
    }

    // MARK: - Grass mound (catches the falling fruit)

    private func buildGrass() {
        let mound = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.6,
                                                   height: 320))
        mound.fillColor = UIColor(hex: "#A7F3D0")
        mound.strokeColor = .clear
        mound.position = CGPoint(x: 0, y: groundY - 130)
        mound.zPosition = -2
        addChild(mound)

        // Brighter rim line to define the horizon
        let rim = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.6,
                                                 height: 320 + 6))
        rim.fillColor = .clear
        rim.strokeColor = UIColor(hex: "#86EFAC").withAlphaComponent(0.7)
        rim.lineWidth = 4
        rim.position = mound.position
        rim.zPosition = -1
        addChild(rim)

        // Grass tufts and daisies
        for _ in 0..<14 {
            let tuft = makeGrassTuft()
            tuft.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 20 ... size.width / 2 - 20),
                y: groundY + CGFloat.random(in: -16...12))
            tuft.zPosition = 4
            addChild(tuft)
        }
        for _ in 0..<6 {
            let daisy = makeDaisy()
            daisy.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 + 24 ... size.width / 2 - 24),
                y: groundY + CGFloat.random(in: -10...10))
            daisy.zPosition = 5
            addChild(daisy)
        }
    }

    // MARK: - Loading dots indicator

    private func buildLoadingDots() {
        let dotsParent = SKNode()
        dotsParent.position = CGPoint(x: 0, y: -size.height * 0.42)
        dotsParent.zPosition = 110
        addChild(dotsParent)

        for i in 0..<3 {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = UIColor.white.withAlphaComponent(0.95)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat(i - 1) * 16, y: 0)
            dot.alpha = 0.4
            dotsParent.addChild(dot)

            dot.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i) * 0.15),
                .group([.scale(to: 1.6, duration: 0.35),
                        .fadeAlpha(to: 1.0, duration: 0.35)]),
                .group([.scale(to: 1.0, duration: 0.35),
                        .fadeAlpha(to: 0.4, duration: 0.35)]),
                .wait(forDuration: 0.45 - Double(i) * 0.15)
            ])))
        }
    }

    // MARK: - Decoration helpers

    private func makeGrassTuft() -> SKNode {
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

    // MARK: - Bokeh background orbs

    private func spawnBokeh() {
        let palette = [
            UIColor(hex: "#FBCFE8").withAlphaComponent(0.35), // pastel pink
            UIColor(hex: "#A7F3D0").withAlphaComponent(0.35), // mint
            UIColor(hex: "#FED7AA").withAlphaComponent(0.32), // peach
            UIColor(hex: "#DDD6FE").withAlphaComponent(0.32), // lavender
            UIColor(hex: "#BAE6FD").withAlphaComponent(0.32)  // powder blue
        ]
        for _ in 0..<8 {
            let radius = CGFloat.random(in: 60...130)
            let orb = SKShapeNode(circleOfRadius: radius)
            orb.fillColor = palette.randomElement()!
            orb.strokeColor = .clear
            orb.glowWidth = 20
            orb.blendMode = .add
            orb.zPosition = -50
            orb.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2 ... size.width / 2),
                y: CGFloat.random(in: -size.height / 2 ... size.height / 2)
            )
            addChild(orb)

            // Drifting animation: slow upward + horizontal sway + breathing scale
            let driftDur = TimeInterval.random(in: 9...14)
            let dx = CGFloat.random(in: -50...50)
            let dy = CGFloat.random(in: 80...160)
            orb.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: driftDur),
                    .scale(to: 1.15, duration: driftDur),
                    .fadeAlpha(to: 0.5, duration: driftDur)
                ]),
                .group([
                    .moveBy(x: -dx, y: -dy, duration: driftDur),
                    .scale(to: 1.0, duration: driftDur),
                    .fadeAlpha(to: 0.32, duration: driftDur)
                ])
            ])))
        }
    }

    // MARK: - Ambient sparkles

    private func spawnAmbientSparkles() {
        let action = SKAction.run { [weak self] in self?.emitSparkle() }
        run(.repeatForever(.sequence([
            action,
            .wait(forDuration: 0.18)
        ])))
    }

    private func emitSparkle() {
        let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...2.4))
        dot.fillColor = .white
        dot.strokeColor = .clear
        dot.glowWidth = 4
        dot.blendMode = .add
        dot.zPosition = 50
        dot.position = CGPoint(
            x: CGFloat.random(in: -size.width / 2 ... size.width / 2),
            y: CGFloat.random(in: -size.height / 2 ... size.height / 2)
        )
        dot.alpha = 0
        dot.setScale(0.4)
        addChild(dot)

        let life = TimeInterval.random(in: 1.2...2.4)
        dot.run(.sequence([
            .group([
                .scale(to: 1.6, duration: life * 0.4),
                .fadeAlpha(to: 1.0, duration: life * 0.3)
            ]),
            .group([
                .scale(to: 0.2, duration: life * 0.6),
                .fadeOut(withDuration: life * 0.6)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Falling fruits

    private func startFruitSpawner() {
        let spawn = SKAction.run { [weak self] in self?.spawnFruit() }
        let wait = SKAction.wait(forDuration: 0.42, withRange: 0.18)
        run(.repeatForever(.sequence([spawn, wait])), withKey: "fruitSpawner")
    }

    private func startBombSpawner() {
        // Drop a bomb roughly every 1.6 seconds — rarer than fruits.
        let spawn = SKAction.run { [weak self] in self?.spawnBomb() }
        let wait = SKAction.wait(forDuration: 1.6, withRange: 0.6)
        run(.repeatForever(.sequence([wait, spawn])), withKey: "bombSpawner")
    }

    private func spawnBomb() {
        guard size.width > 100, size.height > 100 else { return }
        let bomb = makeBomb(size: CGFloat.random(in: 42...58))
        let startX = CGFloat.random(in: -size.width / 2 + 30 ... size.width / 2 - 30)
        let startY = size.height / 2 + 70
        bomb.position = CGPoint(x: startX, y: startY)
        bomb.alpha = 0
        bomb.zPosition = 6
        addChild(bomb)

        let fallDur = TimeInterval.random(in: 2.4...3.2)
        let rotateDir: CGFloat = Bool.random() ? 1 : -1
        let totalRotation = CGFloat.random(in: 0.4...1.2) * rotateDir

        bomb.run(.fadeAlpha(to: 1.0, duration: 0.3))
        bomb.run(.repeatForever(.rotate(byAngle: totalRotation, duration: fallDur)),
                 withKey: "spin")

        bomb.run(.sequence([
            .move(to: CGPoint(x: startX + CGFloat.random(in: -20...20), y: groundY),
                  duration: fallDur),
            .run { [weak self, weak bomb] in
                guard let self = self, let bomb = bomb else { return }
                self.bombPuff(at: bomb.position)
                bomb.removeFromParent()
            }
        ]))
    }

    /// A "boom" puff effect when a bomb hits the ground — yellow/orange glow.
    private func bombPuff(at point: CGPoint) {
        for _ in 0..<8 {
            let s = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            s.fillColor = UIColor(hex: "#FBBF24")
            s.strokeColor = .clear
            s.glowWidth = 6
            s.blendMode = .add
            s.position = point
            s.zPosition = 7
            addChild(s)
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 30...60)
            s.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist),
                          duration: 0.55),
                    .scale(to: 0.2, duration: 0.55),
                    .fadeOut(withDuration: 0.55)
                ]),
                .removeFromParent()
            ]))
        }
        // Soft orange flash
        let flash = SKShapeNode(circleOfRadius: 30)
        flash.fillColor = UIColor(hex: "#F97316").withAlphaComponent(0.65)
        flash.strokeColor = .clear
        flash.glowWidth = 14
        flash.blendMode = .add
        flash.position = point
        flash.zPosition = 6
        addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.5),
                    .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    /// Mini cartoon bomb — same look as the home page.
    private func makeBomb(size: CGFloat) -> SKNode {
        let node = SKNode()

        let body = SKShapeNode(circleOfRadius: size / 2)
        body.fillColor = UIColor(hex: "#1F2937")
        body.strokeColor = UIColor(hex: "#374151")
        body.lineWidth = 2
        node.addChild(body)

        let inner = SKShapeNode(circleOfRadius: size / 2 - 5)
        inner.fillColor = UIColor(hex: "#374151")
        inner.strokeColor = .clear
        inner.alpha = 0.6
        node.addChild(inner)

        let shine = SKShapeNode(ellipseOf: CGSize(width: size * 0.35,
                                                   height: size * 0.18))
        shine.fillColor = UIColor.white.withAlphaComponent(0.5)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -size * 0.16, y: size * 0.18)
        node.addChild(shine)

        let cap = SKShapeNode(rectOf: CGSize(width: size * 0.20, height: size * 0.10),
                               cornerRadius: 2)
        cap.fillColor = UIColor(hex: "#92400E")
        cap.strokeColor = .clear
        cap.position = CGPoint(x: 0, y: size * 0.54)
        node.addChild(cap)

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
        node.addChild(fuse)

        let halo = SKShapeNode(circleOfRadius: size * 0.28)
        halo.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.55)
        halo.strokeColor = .clear
        halo.glowWidth = 6
        halo.blendMode = .add
        halo.position = CGPoint(x: size * 0.18, y: size * 0.92)
        node.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.2, duration: 0.30),
                    .fadeAlpha(to: 0.85, duration: 0.30)]),
            .group([.scale(to: 0.9, duration: 0.30),
                    .fadeAlpha(to: 0.4, duration: 0.30)])
        ])))

        let spark = SKLabelNode(text: "✦")
        spark.fontName = "AvenirNext-Heavy"
        spark.fontSize = size * 0.4
        spark.fontColor = UIColor(hex: "#FBBF24")
        spark.verticalAlignmentMode = .center
        spark.horizontalAlignmentMode = .center
        spark.position = CGPoint(x: size * 0.18, y: size * 0.92)
        node.addChild(spark)

        return node
    }

    private func spawnFruit() {
        guard size.width > 100, size.height > 100 else { return }
        let fontSize = CGFloat.random(in: 36...62)
        let label = SKSpriteNode(texture: Theme.emojiTexture(fruits.randomElement()!))
        label.size = CGSize(width: fontSize * 1.3, height: fontSize * 1.3)
        label.zPosition = 5
        label.alpha = 0

        let startX = CGFloat.random(in: -size.width / 2 + 30 ... size.width / 2 - 30)
        let startY = size.height / 2 + 60
        label.position = CGPoint(x: startX, y: startY)
        addChild(label)

        let fallDur = TimeInterval.random(in: 2.6...3.6)
        let drift = CGFloat.random(in: -40...40)
        let rotateDir: CGFloat = Bool.random() ? 1 : -1
        let totalRotation = CGFloat.random(in: 0.8...2.2) * rotateDir

        // Sine-wave horizontal sway via a path
        let path = UIBezierPath()
        path.move(to: label.position)
        let steps = 24
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let y = startY - (startY - groundY) * t
            let sway = sin(t * .pi * 2.5) * 18 + drift * t
            path.addLine(to: CGPoint(x: startX + sway, y: y))
        }

        let fall = SKAction.follow(path.cgPath, asOffset: false, orientToPath: false, duration: fallDur)
        fall.timingMode = .easeIn

        label.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.3),
        ]))
        label.run(.repeatForever(.rotate(byAngle: totalRotation, duration: fallDur)),
                  withKey: "spin")

        label.run(.sequence([
            fall,
            .run { [weak self, weak label] in
                guard let self = self, let label = label else { return }
                self.smashFruit(at: label.position, fontSize: fontSize)
                label.removeFromParent()
            }
        ]))
    }

    private func smashFruit(at point: CGPoint, fontSize: CGFloat) {
        // Soft "puff" cloud — cream and pink dots expanding outward, low velocity
        let puff = SKEmitterNode()
        puff.particleTexture = makeSoftDotTexture(diameter: 14)
        puff.particleColor = UIColor(hex: "#FFF7ED")
        puff.particleColorBlendFactor = 1.0
        puff.numParticlesToEmit = 18
        puff.particleBirthRate = 800
        puff.particleLifetime = 1.0
        puff.particleLifetimeRange = 0.4
        puff.emissionAngle = 0
        puff.emissionAngleRange = .pi * 2
        puff.particleSpeed = 60
        puff.particleSpeedRange = 30
        puff.particleAlpha = 0.85
        puff.particleAlphaRange = 0.2
        puff.particleAlphaSpeed = -0.85
        puff.particleScale = 0.9
        puff.particleScaleRange = 0.4
        puff.particleScaleSpeed = 0.4 // grow as they drift
        puff.yAcceleration = 30 // slight upward drift to feel airy
        puff.position = point
        puff.zPosition = 6
        puff.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(hex: "#FFF7ED").withAlphaComponent(0.95),
            UIColor(hex: "#FBCFE8").withAlphaComponent(0.8),
            UIColor.white.withAlphaComponent(0.0)
        ], times: [0.0, 0.5, 1.0])
        puff.particleBlendMode = .add
        addChild(puff)
        puff.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))

        // Tiny "glitter" burst — a few sparkle dots flying outward
        for _ in 0..<6 {
            let s = SKShapeNode(circleOfRadius: 1.8)
            s.fillColor = .white
            s.strokeColor = .clear
            s.glowWidth = 3
            s.blendMode = .add
            s.position = point
            s.zPosition = 7
            addChild(s)
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 20...40)
            s.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist), duration: 0.5),
                    .scale(to: 0.2, duration: 0.5),
                    .fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func makeSoftDotTexture(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors as CFArray,
                                       locations: [0.0, 1.0])!
            cg.drawRadialGradient(gradient,
                                  startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: diameter / 2,
                                  options: [])
        }
        return SKTexture(image: img)
    }
}
