import SpriteKit

// Idle hint (suggested move)
extension GameScene {
    // MARK: - Idle hint (suggested move)

    /// Schedule a hint to appear after `idleHintDelay` seconds of no input. Any
    /// existing pending hint is replaced.
    func scheduleIdleHint() {
        cancelIdleHint()
        // Don't schedule if a modal/menu/booster is up or the level just ended.
        guard !levelEnded,
              modalCard == nil,
              settingsCard == nil,
              shopCard == nil,
              endLevelCard == nil,
              boosterMode == .none else { return }
        guard shouldOfferIdleHint else { return }

        let delay = SKAction.wait(forDuration: idleHintDelay)
        let show  = SKAction.run { [weak self] in self?.showIdleHint(force: false) }
        run(.sequence([delay, show]), withKey: "idleHint")
    }

    var shouldOfferIdleHint: Bool {
        guard hintShownThisLevel < 2 else { return false }
        return Engine.findHintMove(grid) != nil
    }

    func cancelIdleHint() {
        removeAction(forKey: "idleHint")
        for ring in hintRings { ring.removeFromParent() }
        hintRings.removeAll()
        for tile in hintTiles {
            tile.removeAction(forKey: "hintPulse")
            tile.run(.scale(to: 1.0, duration: 0.10))
        }
        hintTiles.removeAll()
        hintArrow?.removeFromParent()
        hintArrow = nil
    }

    func showIdleHint(force: Bool = false) {
        // Re-check that conditions are still right before drawing anything.
        guard !isResolving, !levelEnded,
              modalCard == nil, settingsCard == nil,
              shopCard == nil, endLevelCard == nil,
              boosterMode == .none else { return }
        guard force || shouldOfferIdleHint else { return }
        guard let move = Engine.findHintMove(grid) else { return }
        guard let nodeA = nodes[move.0.r][move.0.c],
              let nodeB = nodes[move.1.r][move.1.c] else { return }
        hintShownThisLevel += 1

        // Soft yellow rings under the suggested pair, breathing in/out
        for n in [nodeA, nodeB] {
            let ring = makeHintRing(radius: tileSize * 0.55)
            ring.position = n.position
            ring.zPosition = n.zPosition - 0.5
            worldNode.addChild(ring)
            hintRings.append(ring)
        }

        // Pulse each tile so the player can clearly see the move
        let pulse = SKAction.repeatForever(.sequence([
            .scale(to: 1.16, duration: 0.45),
            .scale(to: 1.0,  duration: 0.45)
        ]))
        nodeA.run(pulse, withKey: "hintPulse")
        nodeB.run(pulse, withKey: "hintPulse")
        hintTiles = [nodeA, nodeB]

        // Arrow connecting the two tiles, telling the player which way to swipe
        let arrow = makeHintArrow(from: nodeA.position, to: nodeB.position)
        worldNode.addChild(arrow)
        hintArrow = arrow
    }

    func makeHintRing(radius: CGFloat) -> SKNode {
        let node = SKNode()
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.fillColor = UIColor(hex: "#FACC15").withAlphaComponent(0.25)
        ring.strokeColor = UIColor(hex: "#FBBF24")
        ring.lineWidth = 3
        ring.glowWidth = 8
        ring.alpha = 0.95
        node.addChild(ring)
        ring.run(.repeatForever(.sequence([
            .group([.scale(to: 1.18, duration: 0.55),
                    .fadeAlpha(to: 0.45, duration: 0.55)]),
            .group([.scale(to: 1.0, duration: 0.55),
                    .fadeAlpha(to: 0.95, duration: 0.55)])
        ])))
        return node
    }

    func makeHintArrow(from a: CGPoint, to b: CGPoint) -> SKNode {
        let node = SKNode()
        node.zPosition = 600

        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(0.001, hypot(dx, dy))
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let angle = atan2(dy, dx)

        // Arrow shaft
        let shaft = SKShapeNode(rectOf: CGSize(width: len * 0.55, height: 5),
                                  cornerRadius: 2.5)
        shaft.fillColor = UIColor(hex: "#FBBF24")
        shaft.strokeColor = UIColor(hex: "#92400E")
        shaft.lineWidth = 1
        shaft.position = mid
        shaft.zRotation = angle
        node.addChild(shaft)

        // Arrowhead — small triangle at the destination side
        let headPath = UIBezierPath()
        headPath.move(to: CGPoint(x: 0, y: 0))
        headPath.addLine(to: CGPoint(x: -10, y: 6))
        headPath.addLine(to: CGPoint(x: -10, y: -6))
        headPath.close()
        let head = SKShapeNode(path: headPath.cgPath)
        head.fillColor = UIColor(hex: "#FBBF24")
        head.strokeColor = UIColor(hex: "#92400E")
        head.lineWidth = 1
        head.position = b
        head.zRotation = angle
        node.addChild(head)

        // Bidirectional bob — shaft slides slightly back-and-forth like "swipe"
        let bobDistance: CGFloat = 5
        let dxNorm = dx / len
        let dyNorm = dy / len
        node.run(.repeatForever(.sequence([
            .move(by: CGVector(dx: dxNorm * bobDistance,
                                dy: dyNorm * bobDistance), duration: 0.45),
            .move(by: CGVector(dx: -dxNorm * bobDistance,
                                dy: -dyNorm * bobDistance), duration: 0.45)
        ])))
        return node
    }

    func nodeIdMap(in oldGrid: Grid) -> [String: SKNode] {
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
