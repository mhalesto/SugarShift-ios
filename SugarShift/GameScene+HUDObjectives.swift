import SpriteKit

extension GameScene {
    /// Expand only a known, fixed blocker inventory. Spreading chocolate keeps
    /// its aggregate goal, since newly spawned blockers also count toward it.
    var displayedHUDObjectives: [LevelObjective] {
        let layout = levelConfig.layout
        let inventory: [(BlockerType, Int)] = [
            (.ice, layout.iceCount), (.jelly, layout.jellyCount),
            (.lock, layout.lockCount), (.crate, layout.crateCount),
            (.colorLock, layout.colorLockCount), (.chest, layout.chestCount),
            (.vine, layout.vineCount), (.countdown, layout.countdownCount)
        ].filter { $0.1 > 0 }
        let expanded = levelConfig.objectives.flatMap { objective -> [LevelObjective] in
            guard case .breakBlockers(let count) = objective, levelConfig.definition == nil,
                  layout.chocolateCount == 0, inventory.reduce(0, { $0 + $1.1 }) == count else { return [objective] }
            return inventory.map { .destroySpecificBlocker(type: $0.0, count: $0.1) }
        }
        return expanded.count <= 4 ? expanded : levelConfig.objectives
    }

    func hudProgress(for objective: LevelObjective) -> ObjectiveProgress {
        if !levelConfig.objectives.contains(objective), case .destroySpecificBlocker(let type, let count) = objective {
            return ObjectiveProgress(objective: objective, current: min(count, objectiveTracker.destroyedBlockers[type, default: 0]))
        }
        return objectiveTracker.progress(for: objective)
    }

    func makeHUDObjectiveIcon(_ objective: LevelObjective, size: CGFloat) -> SKNode {
        if GameArt.texture(objective.artName) != nil {
            return GameArt.sprite(objective.artName, fitting: CGSize(width: size, height: size))
        }
        let root = SKNode()
        switch objective {
        case .collectKeys:
            // A molded key silhouette, also legible without a separate atlas.
            let key = SKNode()
            let stem = GameSurface.panel(size: CGSize(width: size * 0.19, height: size * 0.62), top: UIColor(hex: "#FFE97E"), bottom: UIColor(hex: "#EB9B12"), radius: size * 0.06, rim: UIColor(hex: "#B86B09"))
            stem.position.y = -size * 0.12
            key.addChild(stem)
            let ring = SKShapeNode(circleOfRadius: size * 0.20)
            ring.fillColor = .clear
            ring.strokeColor = UIColor(hex: "#FFBF2A")
            ring.lineWidth = size * 0.105
            ring.position.y = size * 0.24
            key.addChild(ring)
            for y in [-0.24, -0.36] {
                let tooth = SKShapeNode(rectOf: CGSize(width: size * 0.23, height: size * 0.11), cornerRadius: size * 0.025)
                tooth.fillColor = UIColor(hex: "#F6B424")
                tooth.strokeColor = UIColor(hex: "#D78C16")
                tooth.position = CGPoint(x: size * 0.11, y: size * y)
                key.addChild(tooth)
            }
            key.zRotation = -.pi / 4
            root.addChild(key)
        case .destroySpecificBlocker, .freePieces:
            let blockerType: BlockerType
            if case .destroySpecificBlocker(let type, _) = objective { blockerType = type } else { blockerType = .cage }
            let fruit = GameArt.sprite("fruit_grape", fitting: CGSize(width: size * 0.8, height: size * 0.8))
            root.addChild(fruit)
            BoardRenderer.addBlocker(Blocker(type: blockerType, hits: 1), to: root, size: size, underPiece: false)
        default:
            let ice = GameArt.sprite("blocker_ice_01", fitting: CGSize(width: size * 0.8, height: size * 0.8))
            ice.position = CGPoint(x: -size * 0.13, y: size * 0.08)
            root.addChild(ice)
            let chocolate = GameArt.sprite("blocker_chocolate", fitting: CGSize(width: size * 0.7, height: size * 0.7))
            chocolate.position = CGPoint(x: size * 0.16, y: -size * 0.15)
            root.addChild(chocolate)
        }
        return root
    }
}
