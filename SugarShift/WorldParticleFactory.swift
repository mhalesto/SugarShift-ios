import SpriteKit

enum WorldParticleKind: String {
    case sparkle, glow, chip, leaf, petal, ember, smoke, bubble, ice, honey, sand
    case firefly, butterfly, bee, star, cloud, crystal
}

/// One bounded pool per board. Textures are shared; nothing emits forever per cell.
final class WorldParticleFactory {
    static let liveLimit = 180
    private static var textures: [WorldParticleKind: SKTexture] = [:]
    private var idle: [SKSpriteNode] = []
    private var live: [ObjectIdentifier: SKSpriteNode] = [:]
    var activeCount: Int { live.count }

    static func texture(_ kind: WorldParticleKind) -> SKTexture {
        if let cached = textures[kind] { return cached }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28), format: format).image { context in
            let cg = context.cgContext
            UIColor.white.setFill(); UIColor.white.setStroke()
            let path = UIBezierPath()
            switch kind {
            case .glow, .smoke, .cloud:
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    cg.drawRadialGradient(gradient, startCenter: CGPoint(x: 14, y: 14), startRadius: 1,
                        endCenter: CGPoint(x: 14, y: 14), endRadius: 14, options: [])
                }
            case .bubble:
                let ring = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 22, height: 22))
                ring.lineWidth = 1.8; ring.stroke()
                UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 5, height: 5)).fill()
            case .sparkle, .star:
                for i in 0..<10 {
                    let angle = CGFloat(i) * .pi / 5 - .pi / 2
                    let radius: CGFloat = i.isMultiple(of: 2) ? 12 : 4.5
                    let p = CGPoint(x: 14 + cos(angle) * radius, y: 14 + sin(angle) * radius)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.close(); path.fill()
            case .leaf, .petal:
                path.move(to: CGPoint(x: 3, y: 24))
                path.addCurve(to: CGPoint(x: 25, y: 3), controlPoint1: CGPoint(x: 0, y: 2), controlPoint2: CGPoint(x: 22, y: 1))
                path.addCurve(to: CGPoint(x: 3, y: 24), controlPoint1: CGPoint(x: 27, y: 22), controlPoint2: CGPoint(x: 6, y: 27))
                path.fill()
            case .honey:
                path.move(to: CGPoint(x: 14, y: 2))
                path.addCurve(to: CGPoint(x: 14, y: 26), controlPoint1: CGPoint(x: 37, y: 22), controlPoint2: CGPoint(x: 20, y: 27))
                path.addCurve(to: CGPoint(x: 14, y: 2), controlPoint1: CGPoint(x: -6, y: 27), controlPoint2: CGPoint(x: 4, y: 16))
                path.fill()
            case .firefly:
                UIBezierPath(ovalIn: CGRect(x: 10, y: 7, width: 8, height: 16)).fill()
                UIColor.white.withAlphaComponent(0.6).setFill()
                UIBezierPath(ovalIn: CGRect(x: 1, y: 4, width: 12, height: 9)).fill()
                UIBezierPath(ovalIn: CGRect(x: 15, y: 4, width: 12, height: 9)).fill()
            case .butterfly:
                for x: CGFloat in [2, 15] {
                    UIBezierPath(ovalIn: CGRect(x: x, y: 3, width: 11, height: 14)).fill()
                    UIBezierPath(ovalIn: CGRect(x: x + 1, y: 15, width: 9, height: 9)).fill()
                }
                UIBezierPath(roundedRect: CGRect(x: 12, y: 6, width: 4, height: 19), cornerRadius: 2).fill()
            case .bee:
                UIColor.white.withAlphaComponent(0.65).setFill()
                UIBezierPath(ovalIn: CGRect(x: 2, y: 3, width: 11, height: 10)).fill()
                UIBezierPath(ovalIn: CGRect(x: 15, y: 3, width: 11, height: 10)).fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 9, y: 7, width: 10, height: 17)).fill()
                UIColor(white: 0.4, alpha: 0.9).setStroke()
                for y: CGFloat in [13, 18] {
                    let stripe = UIBezierPath(); stripe.move(to: CGPoint(x: 10, y: y))
                    stripe.addLine(to: CGPoint(x: 18, y: y)); stripe.lineWidth = 2; stripe.stroke()
                }
            case .ice, .crystal, .chip:
                path.move(to: CGPoint(x: 4, y: 6)); path.addLine(to: CGPoint(x: 18, y: 2))
                path.addLine(to: CGPoint(x: 26, y: 16)); path.addLine(to: CGPoint(x: 11, y: 26))
                path.close(); path.fill()
                UIColor(white: 0.65, alpha: 1).setStroke(); path.lineWidth = 2; path.stroke()
            case .ember, .sand:
                UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 12, height: 12)).fill()
            }
        }
        let result = SKTexture(image: image); result.filteringMode = .linear
        textures[kind] = result
        return result
    }

    @discardableResult
    func spawn(_ kind: WorldParticleKind, at origin: CGPoint, in parent: SKNode, color: UIColor,
               size: CGFloat, life: TimeInterval, velocity: CGVector = .zero,
               gravity: CGFloat = 0, target: CGPoint? = nil, index: Int = 0,
               path: CGPath? = nil) -> SKSpriteNode? {
        guard live.count < Self.liveLimit, !SignatureMotion.isReduced else { return nil }
        let particle = idle.popLast() ?? SKSpriteNode()
        particle.texture = Self.texture(kind)
        particle.size = CGSize(width: size, height: size)
        particle.position = origin; particle.alpha = 1; particle.setScale(1)
        particle.zRotation = 0; particle.color = color; particle.colorBlendFactor = 1
        particle.blendMode = [.glow, .firefly, .ember, .sparkle].contains(kind) ? .add : .alpha
        particle.zPosition = 1
        let id = ObjectIdentifier(particle); live[id] = particle
        parent.addChild(particle)
        let duration = min(0.9, max(0.12, life))
        let travel: SKAction
        if let path {
            travel = .follow(path, asOffset: false, orientToPath: false, duration: duration)
        } else if let target {
            let arc = UIBezierPath(); arc.move(to: origin)
            let bend = CGFloat(index.isMultiple(of: 2) ? 1 : -1) * max(24, abs(target.y - origin.y) * 0.25)
            arc.addCurve(to: target,
                controlPoint1: CGPoint(x: origin.x + bend, y: origin.y + 48),
                controlPoint2: CGPoint(x: target.x - bend * 0.35, y: target.y - 30))
            travel = .follow(arc.cgPath, asOffset: false, orientToPath: kind == .firefly, duration: duration)
        } else {
            travel = .customAction(withDuration: duration) { node, elapsed in
                let t = CGFloat(elapsed)
                node.position = CGPoint(x: origin.x + velocity.dx * t,
                    y: origin.y + velocity.dy * t - 0.5 * gravity * t * t)
            }
        }
        let fade = SKAction.sequence([.wait(forDuration: duration * 0.55), .fadeOut(withDuration: duration * 0.45)])
        let spin: CGFloat = [.bubble, .glow, .firefly, .butterfly, .bee].contains(kind) ? 0 : CGFloat(index.isMultiple(of: 2) ? 2.2 : -1.7)
        let scaling: SKAction
        if [.butterfly, .bee].contains(kind) {
            scaling = .customAction(withDuration: duration) { node, elapsed in
                let progress = min(1, CGFloat(elapsed) / CGFloat(duration))
                let scale = 1 - progress * 0.45
                node.xScale = scale * (0.64 + 0.36 * cos(CGFloat(elapsed) * 32))
                node.yScale = scale
            }
        } else {
            scaling = .scale(to: kind == .smoke || kind == .cloud ? 2 : 0.4, duration: duration)
        }
        particle.run(.sequence([.group([travel, fade, .rotate(byAngle: spin, duration: duration), scaling]),
            .run { [weak self, weak particle] in if let particle { self?.recycle(particle) } }]))
        return particle
    }

    func burst(_ kind: WorldParticleKind, at point: CGPoint, in parent: SKNode,
               profile: WorldAnimationProfile, count: Int, radius: CGFloat, scale: CGFloat = 1) {
        let count = min(count, Self.liveLimit - live.count)
        guard count > 0 else { return }
        for i in 0..<count {
            let angle = CGFloat(i) * 2.399963
            let speed = radius * (0.9 + CGFloat(i % 4) * 0.17)
            let side = max(3, min(16, radius * 0.13)) * scale
            spawn(kind, at: point, in: parent, color: UIColor(hex: i.isMultiple(of: 3) ? profile.secondary : profile.tint),
                size: side, life: profile.destructionDuration + 0.2,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed + 30),
                gravity: CGFloat(profile.gravity), index: i)
        }
    }

    func reset() {
        for particle in Array(live.values) { recycle(particle) }
    }

    private func recycle(_ particle: SKSpriteNode) {
        guard live.removeValue(forKey: ObjectIdentifier(particle)) != nil else { return }
        particle.removeAllActions(); particle.removeFromParent()
        if idle.count < 80 { idle.append(particle) }
    }
}
