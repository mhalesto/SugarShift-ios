import SpriteKit

/// Lightweight single-special choreography. Footprints come from the captured
/// resolution, and the owning material layer clips every effect to the board.
enum SingleSpecialAnimator {
    static func make(plan: SpecialPresentationPlan, affected: Set<Pos>, points: [Pos: CGPoint],
                     tile: CGFloat, tint: UIColor, delay: TimeInterval,
                     pan: Float, playsSound: Bool) -> SKNode {
        let root = SKNode()
        root.name = "singleSpecialActivation"
        let time = SignatureMotion.isReduced ? 0 : delay
        guard let origin = points[plan.origin] else { return root }
        if playsSound {
            let sound: Audio.SFX
            switch plan.special {
            case .stripedRow, .stripedCol, .lineBlast, .rocket: sound = .stripe
            case .wrapped: sound = .wrapped
            case .colorBomb: sound = .colorCharge
            case .fish: sound = .fish
            case .bomb, .ufo: sound = .bomb
            }
            root.run(.sequence([.wait(forDuration: time), .run { Audio.shared.play(sound, pan: pan) }]))
        }
        SignatureMotion.remove(root, after: time + 0.95)
        if SignatureMotion.isReduced {
            root.addChild(SignatureMotion.quietMark(at: origin, tint: tint, radius: tile * 0.35))
            return root
        }

        let footprint = plan.footprint.intersection(affected)
        let crop = SKCropNode()
        let path = CGMutablePath()
        for position in footprint {
            guard let point = points[position] else { continue }
            path.addRect(CGRect(x: point.x - tile / 2, y: point.y - tile / 2, width: tile, height: tile))
        }
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white; mask.strokeColor = .clear
        crop.maskNode = mask
        root.addChild(crop)

        func glow(at point: CGPoint, side: CGFloat, time: TimeInterval, color: UIColor? = nil) {
            let light = SKSpriteNode(texture: WorldParticleFactory.texture(.glow))
            light.position = point; light.size = CGSize(width: side, height: side)
            light.color = color ?? tint; light.colorBlendFactor = 1; light.blendMode = .add; light.alpha = 0
            crop.addChild(light)
            light.run(.sequence([.wait(forDuration: max(0, time)), .fadeAlpha(to: 0.68, duration: 0.04),
                .group([.scale(to: 1.35, duration: 0.20), .fadeOut(withDuration: 0.20)]), .removeFromParent()]))
        }
        func pulse(at point: CGPoint, time: TimeInterval, radius: CGFloat) {
            let ring = SKShapeNode(circleOfRadius: tile * 0.15)
            ring.position = point; ring.fillColor = .clear; ring.strokeColor = tint
            ring.lineWidth = 3; ring.glowWidth = 2; ring.alpha = 0
            crop.addChild(ring)
            ring.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.025),
                .group([.scale(to: radius / (tile * 0.15), duration: 0.24),
                        .fadeOut(withDuration: 0.24)]), .removeFromParent()]))
        }
        func lane(horizontal: Bool, at time: TimeInterval) {
            let values = footprint.filter { horizontal ? $0.r == plan.origin.r : $0.c == plan.origin.c }
                .compactMap { points[$0] }.sorted { horizontal ? $0.x < $1.x : $0.y < $1.y }
            for end in [values.first, values.last].compactMap({ $0 }) where end != origin {
                crop.addChild(Effects.makeEnergySweep(from: origin, to: end, tint: tint,
                    width: min(12, tile * 0.24), delay: time))
            }
        }
        func token(_ special: Special, at point: CGPoint, scale: CGFloat = 0.85) -> SKSpriteNode {
            let node = GameArt.boardSprite(BoardRenderer.specialAsset(special),
                fitting: CGSize(width: tile * scale, height: tile * scale))
            node.position = point; node.alpha = 0; node.zPosition = 5
            root.addChild(node)
            return node
        }
        func trail(kind: WorldParticleKind, from start: CGPoint, to end: CGPoint,
                   startTime: TimeInterval, duration: TimeInterval, count: Int = 7) {
            for index in 0..<count {
                let fraction = CGFloat(index) / CGFloat(max(1, count - 1))
                let mote = SKSpriteNode(texture: WorldParticleFactory.texture(kind))
                mote.position = CGPoint(x: start.x + (end.x - start.x) * fraction,
                                        y: start.y + (end.y - start.y) * fraction)
                mote.color = tint; mote.colorBlendFactor = 1
                mote.size = CGSize(width: tile * 0.18, height: tile * 0.18)
                mote.alpha = 0; root.addChild(mote)
                mote.run(.sequence([.wait(forDuration: startTime + Double(fraction) * duration),
                    .fadeAlpha(to: 0.75, duration: 0.025),
                    .group([.scale(to: kind == .smoke ? 2.4 : 0.4, duration: 0.20),
                            .fadeOut(withDuration: 0.20)]), .removeFromParent()]))
            }
        }

        switch plan.special {
        case .stripedRow: lane(horizontal: true, at: time)
        case .stripedCol: lane(horizontal: false, at: time)
        case .lineBlast:
            glow(at: origin, side: tile * 1.2, time: time)
            lane(horizontal: true, at: time + 0.02)
            lane(horizontal: false, at: time + 0.055)
        case .rocket:
            let end = footprint.filter { $0.c == plan.origin.c }.compactMap { points[$0] }
                .max { $0.y < $1.y } ?? origin
            let rocket = token(.rocket, at: origin)
            rocket.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.015),
                .group([.scaleX(to: 1.12, duration: 0.05), .scaleY(to: 0.76, duration: 0.05)]),
                .group([.move(to: end, duration: 0.20), .scaleX(to: 0.75, duration: 0.20),
                        .scaleY(to: 1.20, duration: 0.20)]), .fadeOut(withDuration: 0.04), .removeFromParent()]))
            glow(at: origin, side: tile * 1.3, time: time + 0.05, color: UIColor(hex: "#FFE093"))
            trail(kind: .smoke, from: origin, to: end, startTime: time + 0.06, duration: 0.20)
            lane(horizontal: false, at: time + 0.06)
        case .wrapped, .bomb:
            let charge = token(plan.special, at: origin)
            charge.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.02),
                .scale(to: 0.78, duration: 0.035),
                .group([.scale(to: 1.30, duration: 0.09), .fadeOut(withDuration: 0.09)]), .removeFromParent()]))
            pulse(at: origin, time: time + 0.04, radius: tile * 1.3)
            if plan.special == .wrapped { pulse(at: origin, time: time + 0.15, radius: tile * 1.9) }
        case .colorBomb:
            glow(at: origin, side: tile * 1.6, time: time)
            let colors = ["#FF97D9", "#FFEB85", "#A6F8D7", "#99DDFF", "#CFACFF"]
            for (index, position) in footprint.sorted(by: { $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r }).prefix(24).enumerated() {
                guard position != plan.origin, let end = points[position] else { continue }
                let color = UIColor(hex: colors[index % colors.count])
                let arrivesAt = time + plan.travelDelay(to: position)
                let link = UIBezierPath(); link.move(to: origin)
                link.addQuadCurve(to: end, controlPoint: CGPoint(x: (origin.x + end.x) / 2 + tile * 0.3,
                                                               y: (origin.y + end.y) / 2 + tile * 0.3))
                let spark = SKSpriteNode(texture: WorldParticleFactory.texture(.star))
                spark.size = CGSize(width: 8, height: 8); spark.position = origin; spark.alpha = 0
                spark.color = color; spark.colorBlendFactor = 1; root.addChild(spark)
                spark.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.02),
                    .follow(link.cgPath, asOffset: false, orientToPath: false, duration: max(0.06, arrivesAt - time - 0.02)),
                    .fadeOut(withDuration: 0.06), .removeFromParent()]))
                glow(at: end, side: tile, time: arrivesAt, color: color)
            }
            pulse(at: origin, time: time + 0.08, radius: tile * 2)
        case .fish:
            guard let destination = plan.destinations.first(where: { $0 != plan.origin && affected.contains($0) }),
                  let end = points[destination] else { break }
            let fish = token(.fish, at: origin, scale: 0.65)
            let path = UIBezierPath(); path.move(to: origin)
            let control = CGPoint(x: (origin.x + end.x) / 2, y: max(origin.y, end.y) + tile * 0.7)
            path.addQuadCurve(to: end, controlPoint: control)
            fish.xScale = end.x < origin.x ? -1 : 1
            fish.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.04),
                .group([.follow(path.cgPath, asOffset: false, orientToPath: false,
                               duration: SpecialPresentationPlan.seekerTravelDuration),
                        .sequence([.rotate(toAngle: 0.12, duration: 0.08),
                                   .rotate(toAngle: -0.10, duration: 0.08), .rotate(toAngle: 0, duration: 0.08)])]),
                .fadeOut(withDuration: 0.04), .removeFromParent()]))
            for index in 1...5 {
                let t = CGFloat(index) / 6, u = 1 - t
                let point = CGPoint(x: u * u * origin.x + 2 * u * t * control.x + t * t * end.x,
                                    y: u * u * origin.y + 2 * u * t * control.y + t * t * end.y)
                trail(kind: .bubble, from: point, to: CGPoint(x: point.x, y: point.y + 5),
                    startTime: time + 0.04 + Double(t) * SpecialPresentationPlan.seekerTravelDuration,
                    duration: 0.05, count: 1)
            }
            pulse(at: end, time: time + plan.travelDelay(to: destination), radius: tile * 0.7)
        case .ufo:
            let hover = CGPoint(x: origin.x, y: origin.y + tile * 0.5)
            let saucer = token(.ufo, at: origin)
            saucer.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.025),
                .move(to: hover, duration: 0.10), .wait(forDuration: 0.18),
                .group([.moveBy(x: tile * 0.6, y: tile * 0.5, duration: 0.16),
                        .scale(to: 0.4, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
            for (index, position) in footprint.sorted(by: { $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r }).prefix(9).enumerated() {
                guard let end = points[position] else { continue }
                crop.addChild(Effects.makeEnergySweep(from: hover, to: end, tint: tint,
                    width: 4, delay: time + 0.10 + Double(index) * 0.012))
                glow(at: end, side: tile, time: time + plan.travelDelay(to: position))
            }
        }
        return root
    }
}
