import SpriteKit

/// Combo choreography layered beneath the world hero. Every highlight and beam
/// is clipped to the engine's resolved footprint; conversion sprites are visual.
enum BoardSpecialAnimator {
    static func make(plan: ClearPresentationPlan, sequence: WorldComboSequence,
                     affected: Set<Pos>, points: [Pos: CGPoint], tileSize: CGFloat,
                     tint: UIColor) -> SKNode {
        let root = SKNode()
        root.name = "specialComboStages"
        root.zPosition = -1
        guard !SignatureMotion.isReduced, let origin = points[plan.origin] else { return root }
        let crop = SKCropNode()
        let maskPath = CGMutablePath()
        for p in affected {
            guard let point = points[p] else { continue }
            maskPath.addRoundedRect(in: CGRect(x: point.x - tileSize / 2, y: point.y - tileSize / 2,
                width: tileSize, height: tileSize), cornerWidth: 5, cornerHeight: 5)
        }
        let mask = SKShapeNode(path: maskPath)
        mask.fillColor = .white; mask.strokeColor = .clear
        crop.maskNode = mask
        root.addChild(crop)
        let ordered = affected.sorted { a, b in
            let da = plan.delay(for: a), db = plan.delay(for: b)
            return da == db ? (a.r == b.r ? a.c < b.c : a.r < b.r) : da < db
        }
        for p in ordered {
            guard let point = points[p] else { continue }
            let light = SKSpriteNode(texture: WorldParticleFactory.texture(.glow))
            light.size = CGSize(width: tileSize * 1.35, height: tileSize * 1.35)
            light.color = tint; light.colorBlendFactor = 1; light.blendMode = .add
            light.position = point; light.alpha = 0
            crop.addChild(light)
            let arrival = sequence.tileImpactDelay(normalDelay: plan.delay(for: p))
            light.run(.sequence([.wait(forDuration: max(0, arrival - 0.09)),
                .fadeAlpha(to: 0.60, duration: 0.07), .fadeOut(withDuration: 0.16), .removeFromParent()]))
        }

        func pulse(at point: CGPoint, time: TimeInterval, radius: CGFloat) {
            let ring = SKShapeNode(circleOfRadius: tileSize * 0.20)
            ring.position = point; ring.fillColor = .clear; ring.strokeColor = tint
            ring.lineWidth = 5; ring.glowWidth = 3; ring.alpha = 0
            crop.addChild(ring)
            ring.run(.sequence([.wait(forDuration: time), .fadeIn(withDuration: 0.02),
                .group([.scale(to: radius / (tileSize * 0.20), duration: 0.26),
                        .fadeOut(withDuration: 0.26)]), .removeFromParent()]))
        }
        func lane(_ row: Bool, through p: Pos, time: TimeInterval, width: CGFloat = 11) {
            let lane = ordered.filter { row ? $0.r == p.r : $0.c == p.c }
            let coordinates = lane.compactMap { points[$0] }.sorted { row ? $0.x < $1.x : $0.y < $1.y }
            guard let start = coordinates.first, let end = coordinates.last else { return }
            crop.addChild(Effects.makeEnergySweep(from: start, to: end, tint: tint, width: width, delay: time))
        }
        func conversion(_ special: Special) {
            for (index, p) in plan.colorTargets.filter({ affected.contains($0) }).prefix(16).enumerated() {
                guard let point = points[p] else { continue }
                let token = GameArt.boardSprite(BoardRenderer.specialAsset(special),
                    fitting: CGSize(width: tileSize * 0.85, height: tileSize * 0.85))
                token.position = point; token.alpha = 0; token.setScale(0.60)
                crop.addChild(token)
                let formsAt = min(sequence.impactAt * 0.60, 0.07 + Double(index) * 0.012)
                let activationAt = sequence.tileImpactDelay(normalDelay: plan.delay(for: p))
                token.run(.sequence([.wait(forDuration: formsAt),
                    .group([.fadeIn(withDuration: 0.05), .scale(to: 1.08, duration: 0.07)]),
                    .wait(forDuration: max(0, activationAt - formsAt - 0.07)),
                    .group([.scale(to: 1.22, duration: 0.08), .fadeOut(withDuration: 0.08)]), .removeFromParent()]))
            }
        }

        switch plan.kind {
        case .combo(let kind):
            switch kind {
            case .stripeStripe:
                lane(true, through: plan.origin, time: sequence.impactAt)
                lane(false, through: plan.origin, time: sequence.impactAt + 0.035)
            case .wrappedStripe, .bombStripe:
                pulse(at: origin, time: sequence.impactAt - 0.07, radius: tileSize * 1.5)
                for offset in -1...1 {
                    let time = sequence.impactAt + Double(offset + 1) * 0.04
                    lane(true, through: Pos(r: plan.origin.r + offset, c: plan.origin.c), time: time)
                    lane(false, through: Pos(r: plan.origin.r, c: plan.origin.c + offset), time: time + 0.025)
                }
            case .colorStripe:
                let special: Special = plan.firstSpecial == .stripedCol || plan.secondSpecial == .stripedCol ? .stripedCol : .stripedRow
                conversion(special)
                var seen = Set<Int>()
                for p in plan.colorTargets where affected.contains(p) {
                    let coordinate = special == .stripedRow ? p.r : p.c
                    guard seen.insert(coordinate).inserted, seen.count <= 12 else { continue }
                    lane(special == .stripedRow, through: p,
                         time: sequence.tileImpactDelay(normalDelay: plan.delay(for: p)))
                }
            case .colorWrapped, .colorBomb:
                conversion(kind == .colorWrapped ? .wrapped : .bomb)
                for p in plan.colorTargets.filter({ affected.contains($0) }).prefix(10) {
                    if let point = points[p] {
                        pulse(at: point, time: sequence.tileImpactDelay(normalDelay: plan.delay(for: p)), radius: tileSize * 1.5)
                    }
                }
            case .colorColor:
                for index in 0..<3 {
                    pulse(at: origin, time: sequence.impactAt + Double(index) * 0.07,
                          radius: tileSize * CGFloat(4 + index))
                }
            case .wrappedWrapped, .bombWrapped, .bombBomb:
                pulse(at: origin, time: sequence.impactAt, radius: tileSize * 2.4)
                pulse(at: plan.secondary.flatMap { points[$0] } ?? origin,
                      time: sequence.impactAt + 0.13, radius: tileSize * 3.1)
            default:
                pulse(at: origin, time: sequence.impactAt, radius: tileSize * 2)
            }
        case .colorBomb:
            pulse(at: origin, time: sequence.impactAt, radius: tileSize * 2.5)
        case .playerSmash:
            lane(true, through: plan.origin, time: sequence.impactAt, width: 18)
            lane(false, through: plan.origin, time: sequence.impactAt + 0.035, width: 18)
        }
        SignatureMotion.remove(root, after: sequence.finishesAt + 0.05)
        return root
    }
}
