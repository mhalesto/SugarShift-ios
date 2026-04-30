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
        groundY = -size.height * 0.42

        spawnBokeh()
        spawnAmbientSparkles()
        startFruitSpawner()
        revealLogo()

        run(.sequence([
            .wait(forDuration: 3.4),
            .run { [weak self] in self?.onReady?() }
        ]))
    }

    // MARK: - Logo

    private func revealLogo() {
        let logo = BrandLogo.make(fontSize: 56, withTagline: true)
        logo.position = CGPoint(x: 0, y: 0)
        logo.zPosition = 100
        logo.alpha = 0
        logo.setScale(0.4)
        addChild(logo)

        logo.run(.sequence([
            .wait(forDuration: 0.4),
            .group([
                .fadeIn(withDuration: 0.6),
                .sequence([
                    .scale(to: 1.06, duration: 0.55),
                    .scale(to: 1.0, duration: 0.25)
                ])
            ])
        ]))
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

    private func spawnFruit() {
        guard size.width > 100, size.height > 100 else { return }
        let label = SKLabelNode(text: fruits.randomElement()!)
        label.fontSize = CGFloat.random(in: 36...62)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
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
                self.smashFruit(at: label.position, fontSize: label.fontSize)
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
