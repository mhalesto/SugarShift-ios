import SpriteKit

/// Converts semantic events into material reactions. It never mutates the grid,
/// scores, objectives, RNG or the scene's input/resolve state.
final class WorldEffectAnimator {
    private weak var scene: GameScene?
    let particles = WorldParticleFactory()
    private let boardLayer = SKCropNode()
    private let collectionLayer = SKNode()
    private var generation = 0
    private var idleCursor = 0
    private var ready = false
    private var displayedProgress: [Int: ObjectiveProgress] = [:]
    private var pendingArrivals: [Int: Int] = [:]
    private var completedObjectives = Set<Int>()
    private var batchingObjectives = false

    init(scene: GameScene) { self.scene = scene }

    private func attach() {
        guard let scene, scene.worldNode != nil else { return }
        if boardLayer.parent == nil {
            boardLayer.name = "materialEffects"; boardLayer.zPosition = 740
            let mask = SKShapeNode(rect: scene.gameplayLayout.board.insetBy(dx: -2, dy: -2), cornerRadius: 12)
            mask.fillColor = .white; mask.strokeColor = .clear
            boardLayer.maskNode = mask
            scene.worldNode.addChild(boardLayer)
        }
        if collectionLayer.parent == nil {
            collectionLayer.name = "objectiveFlights"; collectionLayer.zPosition = 90
            scene.addChild(collectionLayer)
        }
        if !ready {
            ready = true
            scene.run(.repeatForever(.sequence([.wait(forDuration: 1.8), .run { [weak self] in self?.idleTick() }])), withKey: "worldMaterialIdle")
        }
    }

    func reset(cancelResolution: Bool = true) {
        generation += 1
        if cancelResolution { scene?.worldNode?.removeAction(forKey: "boardResolutionTransition") }
        if let scene { SignatureMotion.cancelFeedback(in: scene) }
        particles.reset()
        boardLayer.removeAllActions(); boardLayer.removeAllChildren(); boardLayer.removeFromParent()
        collectionLayer.removeAllActions(); collectionLayer.removeAllChildren(); collectionLayer.removeFromParent()
        scene?.removeAction(forKey: "worldMaterialIdle")
        ready = false; idleCursor = 0
        displayedProgress.removeAll(); pendingArrivals.removeAll(); completedObjectives.removeAll()
        batchingObjectives = false
    }

    /// Snapshot presentation values before the tracker changes. Logic and saves
    /// update immediately; only the visible readout waits for its collection flight.
    func beginObjectives() -> [ObjectiveProgress] {
        guard let scene else { return [] }
        let before = scene.displayedHUDObjectives.map { scene.hudProgress(for: $0) }
        for (index, progress) in before.enumerated() where displayedProgress[index] == nil {
            displayedProgress[index] = progress
        }
        batchingObjectives = true
        return before
    }

    func finishObjectives(_ before: [ObjectiveProgress], events: [GamePresentationEvent],
                          collected: [Int: [Pos]] = [:], delay: (Pos) -> TimeInterval = { _ in 0 }) {
        guard let scene else { return }
        attach()
        batchingObjectives = false
        for (index, objective) in scene.displayedHUDObjectives.enumerated() where index < before.count {
            let after = scene.hudProgress(for: objective)
            guard after.current > before[index].current else { continue }
            var positions = collected[index] ?? events.filter {
                ObjectivePresentationPolicy.contributes($0, to: objective)
            }.compactMap(\.position)
            var seen = Set<Pos>()
            positions = positions.filter { seen.insert($0).inserted }
            // Six representative flights per objective, never one emitter per item.
            positions = Array(positions.prefix(min(6, after.current - before[index].current)))
            present(positions.map { .objectiveItemCollected(at: $0, objectiveIndex: index) }, delay: delay)
            let lastImpact = SignatureMotion.isReduced ? 0 : (positions.map(delay).max() ?? 0)
            let flightDuration = SignatureMotion.isReduced ? 0.04 : (positions.isEmpty ? 0.12 : 0.54)
            pendingArrivals[index, default: 0] += 1
            let token = generation
            let arrival = SKAction.sequence([.wait(forDuration: flightDuration), .run { [weak self] in
                guard let self, self.generation == token else { return }
                if after.current >= (self.displayedProgress[index]?.current ?? 0) {
                    self.displayedProgress[index] = after
                }
                self.pendingArrivals[index, default: 1] -= 1
                self.writeObjective(index)
                if after.isComplete { self.present([.objectiveCompleted(index: index)]) }
                else { self.objectivePulse(index, complete: false) }
            }])
            boardLayer.run(.sequence([.wait(forDuration: lastImpact), .run { [weak self] in
                guard let self, self.generation == token else { return }
                self.collectionLayer.run(arrival)
            }]))
        }
        synchronizeObjectives()
    }

    /// Called after the existing HUD refresh. Accessibility keeps authoritative
    /// counts; no layout, economy value or footer control is altered here.
    func synchronizeObjectives() {
        guard let scene, scene.headerCard != nil else { return }
        for (index, objective) in scene.displayedHUDObjectives.enumerated() {
            let actual = scene.hudProgress(for: objective)
            if !batchingObjectives, pendingArrivals[index, default: 0] == 0 {
                let previous = displayedProgress[index]
                displayedProgress[index] = actual
                if actual.isComplete, previous?.isComplete == false, scene.gamePhase != .loading {
                    present([.objectiveCompleted(index: index)])
                } else if actual.isComplete, previous == nil {
                    completedObjectives.insert(index)
                }
            }
            writeObjective(index)
        }
    }

    private func writeObjective(_ index: Int) {
        guard let scene, scene.objectiveLabels.indices.contains(index),
              let progress = displayedProgress[index] else { return }
        let label = scene.objectiveLabels[index]
        label.text = "\(progress.current)/\(progress.target)"
        label.fontColor = UIColor(hex: progress.isComplete
            ? (scene.worldTheme.id == "galaxy" ? "#C9FFAF" : "#267632") : scene.worldTheme.cardPalette.ink)
        if progress.isComplete, let target = scene.headerCard?.childNode(withName: "objective:\(index)") {
            installCompletionMarker(on: target)
        } else if !progress.isComplete {
            scene.headerCard?.childNode(withName: "objective:\(index)")?.childNode(withName: "objectiveCheck")?.removeFromParent()
            completedObjectives.remove(index)
        }
    }

    /// Owns the old visual nodes until impact. The scene owns the already-resolved
    /// grid and its node slots; these actions cannot clear an extra cell.
    @discardableResult
    func animateClear(_ result: ClearResult, sources: [Pos: SKNode],
                      delay: (Pos) -> TimeInterval = { _ in 0 }) -> TimeInterval {
        attach()
        for source in sources.values {
            for name in ["emoji", "blockerArt"] {
                source.childNode(withName: name)?.removeAction(forKey: "materialIdle")
            }
        }
        present(result.presentationEvents, sources: sources, delay: delay)
        if let hit = result.presentationEvents.first(where: { if case .blockerHit = $0 { return true }; return false }),
           case .blockerHit(let position, let blocker) = hit, let scene {
            let material = profile(asset: scene.worldTheme.blockerAsset(blocker), blocker: blocker.type).material
            let impactDelay = SignatureMotion.isReduced ? 0 : delay(position)
            boardLayer.run(.sequence([.wait(forDuration: impactDelay), .run {
                // One material cue per batch, using the existing sound preference gates.
                let soft = [AnimationMaterial.honey, .water, .jelly, .cloud, .cream].contains(material)
                Audio.shared.play(soft ? .jelly : material == .ice || material == .crystal ? .swapClick : .crate)
                Effects.haptic(soft ? .soft : .rigid, intensity: blocker.hits <= 1 ? 0.46 : 0.25)
            }]))
        }
        var finishes: TimeInterval = 0.18
        let token = generation
        for position in result.cleared.union(result.damagedBlockers) {
            let time = SignatureMotion.isReduced ? 0 : delay(position)
            let cleared = result.cleared.contains(position)
            let hitDuration = result.presentationEvents.compactMap { event -> TimeInterval? in
                guard case .blockerHit(let p, let blocker) = event, p == position, let scene else { return nil }
                return profile(asset: scene.worldTheme.blockerAsset(blocker), blocker: blocker.type).hitDuration
            }.first ?? 0.18
            let duration = cleared ? 0.18 : hitDuration
            finishes = max(finishes, time + duration)
            guard let source = sources[position] else { continue }
            if cleared {
                source.run(.sequence([.wait(forDuration: time),
                    SignatureMotion.clearAction(), .removeFromParent()]), withKey: "resolvedClear")
            } else {
                // Refresh exactly this surviving cell, after its old layer reacts.
                boardLayer.run(.sequence([.wait(forDuration: time + duration), .run { [weak self, weak source] in
                    guard let self, self.generation == token, let scene = self.scene,
                          let source, scene.nodes[position.r][position.c] === source else { return }
                    let released = source.childNode(withName: "blockerArt") != nil
                        && scene.grid[position.r][position.c]?.blocker == nil
                    scene.refreshNode(at: position)
                    if released, !SignatureMotion.isReduced {
                        scene.nodes[position.r][position.c]?.childNode(withName: "emoji")?.run(.sequence([
                            .scale(to: 0.88, duration: 0.04), .scale(to: 1.10, duration: 0.10),
                            .scale(to: 1, duration: 0.10)]), withKey: "fruitReleased")
                    }
                }]))
            }
        }
        return finishes + 0.02
    }

    func present(_ events: [GamePresentationEvent], sources: [Pos: SKNode] = [:],
                 delay: (Pos) -> TimeInterval = { _ in 0 }) {
        attach()
        let token = generation
        let perEvent = max(2, min(10, 100 / max(1, events.filter {
            switch $0 { case .pieceDestroyed, .blockerDestroyed: return true; default: return false }
        }.count)))
        for event in events {
            let source = event.position.flatMap { sources[$0] }
            let time = event.position.map(delay) ?? 0
            let render = SKAction.run { [weak self, weak source] in
                guard let self, self.generation == token else { return }
                self.render(event, source: source, budget: perEvent)
            }
            boardLayer.run(.sequence([.wait(forDuration: SignatureMotion.isReduced ? 0 : time), render]))
        }
    }

    func presentSpecials(_ plans: [SpecialPresentationPlan], result: ClearResult,
                         timing: CascadePresentationTiming) {
        guard let scene else { return }
        attach()
        let activated = Set(result.presentationEvents.compactMap { event -> Pos? in
            if case .specialActivated(let position, _) = event { return position }
            return nil
        })
        let affected = result.cleared.union(result.damagedBlockers)
        let points = Dictionary(uniqueKeysWithValues: affected.map {
            ($0, scene.point(forRow: $0.r, col: $0.c))
        })
        var sounded = Set<Special>()
        for plan in plans.filter({ activated.contains($0.origin) }).prefix(12) {
            let point = scene.point(forRow: plan.origin.r, col: plan.origin.c)
            let effect = SingleSpecialAnimator.make(plan: plan, affected: affected, points: points,
                tile: scene.tileSize, tint: scene.worldTheme.glowColor,
                delay: timing.activationDelay(plan.origin), pan: scene.soundPan(at: point),
                playsSound: sounded.insert(plan.special).inserted)
            effect.zPosition = 3
            boardLayer.addChild(effect)
        }
    }

    private func profile(asset: String, blocker: BlockerType? = nil) -> WorldAnimationProfile {
        .profile(for: WorldAnimationProfile.material(worldID: scene?.worldTheme.id ?? "candy", asset: asset, blocker: blocker),
                 worldID: scene?.worldTheme.id ?? "candy")
    }

    private func render(_ event: GamePresentationEvent, source: SKNode?, budget: Int) {
        guard let scene else { return }
        let point = event.position.map { scene.point(forRow: $0.r, col: $0.c) } ?? scene.gameplayLayout.board.origin
        switch event {
        case .pieceMatched:
            break // The owning clear action supplies anticipation, once per piece.
        case .pieceDestroyed(_, let piece):
            guard piece.special == nil else { break }
            let asset = scene.worldTheme.pieceAsset(piece.color)
            destroy(profile(asset: asset), asset: asset, at: point,
                    source: source?.childNode(withName: "emoji"), budget: budget)
        case .blockerHit(_, let blocker):
            hit(profile(asset: scene.worldTheme.blockerAsset(blocker), blocker: blocker.type), at: point, source: source, laterHit: blocker.hits <= 2)
        case .blockerDamaged(_, let before, let after):
            let profile = profile(asset: scene.worldTheme.blockerAsset(before), blocker: before.type)
            if [.honey, .jelly, .vine, .seaweed, .cream].contains(profile.material) {
                ribbon(at: point, color: UIColor(hex: profile.secondary),
                       reach: scene.tileSize * 0.50, vertical: profile.material == .vine)
            } else if [.water, .cloud, .flower, .lantern].contains(profile.material) {
                light(at: point, color: UIColor(hex: profile.secondary), size: scene.tileSize, duration: 0.18)
            } else {
                fracture(at: point, color: UIColor(hex: profile.secondary), severity: max(1, 4 - after.hits))
            }
            particles.burst(particleKind(profile.material), at: point, in: boardLayer, profile: profile,
                            count: min(3, budget), radius: scene.tileSize * 0.8, scale: 0.55)
        case .blockerDestroyed(_, let blocker):
            let asset = scene.worldTheme.blockerAsset(blocker)
            destroy(profile(asset: asset, blocker: blocker.type), asset: asset, at: point,
                    source: source?.childNode(withName: "blockerArt"), budget: budget)
            if !SignatureMotion.isReduced {
                source?.childNode(withName: "emoji")?.run(.sequence([.scale(to: 0.88, duration: 0.05),
                    .scale(to: 1.1, duration: 0.10), .scale(to: 1, duration: 0.1)]), withKey: "fruitReleased")
            }
        case .objectiveItemCollected(_, let index):
            collect(from: point, objective: index)
        case .objectiveCompleted(let index): objectivePulse(index, complete: true)
        case .specialCreated(let p, let special):
            specialCreated(special, at: scene.point(forRow: p.r, col: p.c), source: source)
        case .specialActivated(_, let special):
            let color = special == .colorBomb ? UIColor(hex: "#FF93EE") : scene.worldTheme.glowColor
            ring(at: point, color: color, radius: scene.tileSize * 0.7, duration: 0.28)
        case .cascadeAdvanced(let depth): cascade(depth: depth)
        case .portalEntered(let from, let to):
            let start = scene.point(forRow: from.r, col: from.c), end = scene.point(forRow: to.r, col: to.c)
            ring(at: start, color: UIColor(hex: "#BE8CFF"), radius: scene.tileSize * 0.6, duration: 0.22)
            ring(at: end, color: UIColor(hex: "#9EF8FF"), radius: scene.tileSize * 0.6, duration: 0.28)
            for i in 0..<3 { particles.spawn(.glow, at: start, in: boardLayer, color: UIColor(hex: "#D7ADFF"),
                size: 10, life: 0.30, target: end, index: i) }
        case .boardSettled: idleTick()
        case .specialChainTriggered(let positions):
            for (index, p) in positions.prefix(8).enumerated() {
                let start = scene.point(forRow: p.r, col: p.c)
                particles.spawn(.sparkle, at: start, in: boardLayer, color: scene.worldTheme.glowColor,
                    size: 8, life: 0.25 + Double(index) * 0.02, velocity: CGVector(dx: 0, dy: 24))
            }
        case .comboTriggered(_, let positions):
            for p in positions.prefix(2) {
                ring(at: scene.point(forRow: p.r, col: p.c), color: scene.worldTheme.glowColor,
                     radius: scene.tileSize * 0.55, duration: 0.24)
            }
        case .worldComboTriggered: cascade(depth: 4)
        case .pieceCreated, .cascadeStarted: break
        }
    }

    private func particleKind(_ material: AnimationMaterial) -> WorldParticleKind {
        switch material {
        case .firefly, .scarab: return .firefly
        case .vine, .seaweed: return .leaf
        case .flower: return .petal
        case .ice: return .ice
        case .honey: return .honey
        case .lava: return .ember
        case .water: return .bubble
        case .cloud: return .cloud
        case .sandstone, .pottery: return .sand
        case .cosmic, .star, .rainbow: return .star
        case .crystal, .amber: return .crystal
        case .wood, .chocolate, .stone, .metal: return .chip
        case .jelly: return .honey
        case .cream: return .cloud
        case .fruit, .donut, .lantern: return .sparkle
        }
    }

    private func hit(_ profile: WorldAnimationProfile, at point: CGPoint, source: SKNode?, laterHit: Bool) {
        guard let scene else { return }
        light(at: point, color: UIColor(hex: profile.tint), size: scene.tileSize * 1.1, duration: 0.2)
        guard !SignatureMotion.isReduced else { return }
        let art = source?.childNode(withName: "blockerArt") ?? source?.childNode(withName: "emoji")
        art?.removeAction(forKey: "materialIdle")
        if [.honey, .cloud, .water, .jelly, .cream].contains(profile.material) {
            art?.run(.sequence([.group([.scaleX(to: 1.18, duration: 0.07), .scaleY(to: 0.78, duration: 0.07)]),
                .group([.scaleX(to: 0.94, duration: 0.09), .scaleY(to: 1.08, duration: 0.09)]),
                .scale(to: 1, duration: 0.10)]), withKey: "materialHit")
            ribbon(at: point, color: UIColor(hex: profile.tint), reach: scene.tileSize * 0.6, vertical: false)
        } else {
            let amount: CGFloat = laterHit ? 0.11 : 0.065
            art?.run(.sequence([.rotate(toAngle: amount, duration: 0.04),
                .rotate(toAngle: -amount, duration: 0.06), .rotate(toAngle: amount * 0.4, duration: 0.04),
                .rotate(toAngle: 0, duration: 0.06)]), withKey: "materialHit")
        }
        if profile.material == .firefly {
            for index in 0..<3 {
                let tile = scene.tileSize
                let end = CGPoint(x: point.x + CGFloat(index - 1) * tile * 0.12,
                                  y: point.y + tile * (laterHit ? 0.28 : 0.08))
                let path = UIBezierPath(); path.move(to: point)
                path.addCurve(to: end,
                    controlPoint1: CGPoint(x: point.x + tile * 0.15, y: point.y + tile * 0.18),
                    controlPoint2: CGPoint(x: point.x - tile * 0.15, y: end.y - tile * 0.08))
                particles.spawn(.firefly, at: point, in: boardLayer, color: UIColor(hex: profile.secondary),
                    size: tile * 0.10, life: 0.22, index: index, path: path.cgPath)
            }
        }
    }

    private func destroy(_ profile: WorldAnimationProfile, asset: String, at point: CGPoint, source: SKNode?, budget: Int) {
        guard let scene else { return }
        let tile = scene.tileSize, color = UIColor(hex: profile.tint)
        light(at: point, color: color, size: tile * 1.45, duration: 0.22)
        guard !SignatureMotion.isReduced else { return }
        let opensShell = profile.material == .water && asset.contains("shell")
        let releasedArt = opensShell ? nil : destructionCopy(from: source, at: point, material: profile.material)
        switch profile.material {
        case .firefly:
            lid(from: source, at: point, size: tile, color: color)
            ring(at: point, color: color, radius: tile * 0.8, duration: 0.4)
            for i in 0..<min(6, budget) {
                let angle = CGFloat(i) * 2.399963
                let end = CGPoint(x: point.x + cos(angle) * tile, y: point.y + tile * (0.5 + sin(angle)))
                let path = UIBezierPath(); path.move(to: point)
                let side: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                path.addCurve(to: CGPoint(x: point.x, y: point.y + tile * 0.35),
                    controlPoint1: CGPoint(x: point.x + side * tile * 0.45, y: point.y + tile * 0.55),
                    controlPoint2: CGPoint(x: point.x - side * tile * 0.35, y: point.y + tile * 0.70))
                path.addQuadCurve(to: end, controlPoint: CGPoint(x: end.x, y: end.y + tile * 0.4))
                particles.spawn(.firefly, at: point, in: boardLayer, color: UIColor(hex: "#FFF5A1"),
                    size: tile * 0.2, life: 0.62, index: i, path: path.cgPath)
            }
        case .vine, .seaweed:
            for i in 0..<3 { ribbon(at: point, color: color, reach: tile * (0.5 + CGFloat(i) * 0.14), vertical: i.isMultiple(of: 2)) }
            particles.burst(.leaf, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.5)
        case .flower:
            releasedArt?.run(.sequence([.scale(to: 1.22, duration: 0.09), .scale(to: 0.7, duration: 0.22)]))
            for i in 0..<min(3, budget) {
                particles.spawn(.butterfly, at: point, in: boardLayer, color: UIColor(hex: "#FFDDFA"),
                    size: tile * 0.20, life: 0.65,
                    target: CGPoint(x: point.x + CGFloat(i - 1) * tile, y: point.y + tile * 1.4), index: i)
            }
            particles.burst(.petal, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.4)
        case .ice, .crystal, .amber:
            fracture(at: point, color: .white, severity: 3)
            particles.burst(particleKind(profile.material), at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.9, scale: 1.4)
            particles.burst(.smoke, at: point, in: boardLayer, profile: profile, count: 2, radius: tile * 0.5, scale: 2.5)
            ring(at: point, color: color, radius: tile * 1.0, duration: 0.36)
        case .honey:
            if asset.contains("jar") {
                lid(from: source, at: point, size: tile, color: color)
                WorldObjectReleaseAnimator.honeySpiral(at: point, tile: tile, color: color, in: boardLayer)
                particles.spawn(.bee, at: point, in: boardLayer, color: UIColor(hex: "#FFE88A"),
                    size: tile * 0.24, life: 0.60,
                    target: CGPoint(x: point.x + tile * 0.6, y: point.y + tile * 1.2))
            }
            ribbon(at: point, color: color, reach: tile, vertical: true)
            particles.burst(.honey, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.7, scale: 1.3)
        case .donut:
            releasedArt?.run(.rotate(byAngle: .pi * 0.6, duration: 0.28))
            rainbowBurst(at: point, count: budget)
        case .lava:
            fracture(at: point, color: UIColor(hex: "#FFF090"), severity: 3)
            particles.burst(.chip, at: point, in: boardLayer, profile: .profile(for: .wood), count: min(4, budget), radius: tile * 2, scale: 1.7)
            particles.burst(.ember, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 2.1)
            particles.burst(.smoke, at: point, in: boardLayer, profile: profile, count: 2, radius: tile * 0.4, scale: 3)
        case .water:
            if opensShell { WorldObjectReleaseAnimator.openShell(from: source, at: point, tile: tile, in: boardLayer) }
            ring(at: point, color: color, radius: tile, duration: 0.42)
            particles.burst(.bubble, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.2, scale: 1.6)
        case .cloud:
            particles.burst(.cloud, at: point, in: boardLayer, profile: profile, count: min(6, budget), radius: tile, scale: 3)
            rainbowBurst(at: point, count: min(4, budget))
        case .sandstone, .pottery, .wood, .chocolate, .stone, .metal:
            particles.burst(.chip, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 1.2, scale: 1.4)
            particles.burst(.sand, at: point, in: boardLayer, profile: profile, count: budget, radius: tile)
        case .cosmic:
            ring(at: point, color: color, radius: tile, duration: 0.48)
            particles.burst(.chip, at: point, in: boardLayer, profile: profile, count: budget, radius: tile * 0.8, scale: 1.7)
        case .scarab:
            WorldObjectReleaseAnimator.flyingScarab(from: point,
                to: CGPoint(x: point.x + tile * 0.5, y: point.y + tile * 1.5), size: tile * 0.45, in: boardLayer)
            rainbowBurst(at: point, count: min(4, budget))
        case .lantern:
            flyingToken("objective_lantern", at: point, to: CGPoint(x: point.x, y: point.y + tile * 1.8), size: tile * 0.6)
            particles.burst(.glow, at: point, in: boardLayer, profile: profile, count: min(3, budget), radius: tile * 0.5, scale: 2)
        case .star, .rainbow: rainbowBurst(at: point, count: budget)
        case .jelly, .cream:
            ribbon(at: point, color: color, reach: tile * 0.75, vertical: false)
            particles.burst(particleKind(profile.material), at: point, in: boardLayer, profile: profile,
                count: budget, radius: tile * 1.3, scale: 1.5)
        case .fruit:
            particles.burst(.sparkle, at: point, in: boardLayer, profile: profile, count: min(4, budget), radius: tile)
            if boardLayer.children.count < 210 {
                let fragments = Effects.makeFruitFragmentBurst(texture: (source as? SKSpriteNode)?.texture,
                    tint: color, count: min(3, budget), size: tile * 0.25)
                fragments.position = point
                fragments.zPosition = 3
                boardLayer.addChild(fragments)
            }
        }
    }

    private func collect(from start: CGPoint, objective index: Int) {
        guard let scene, scene.displayedHUDObjectives.indices.contains(index),
              let target = scene.headerCard?.childNode(withName: "objective:\(index)") else { return }
        let iconPoint = target.children.first?.position ?? .zero
        let end = scene.convert(iconPoint, from: target)
        let origin = scene.convert(start, from: scene.worldNode)
        if SignatureMotion.isReduced { return }
        let asset = scene.worldTheme.objectiveAsset(scene.displayedHUDObjectives[index])
        let p = profile(asset: asset)
        let kind = particleKind(p.material)
        if p.material == .scarab {
            WorldObjectReleaseAnimator.flyingScarab(from: origin, to: end,
                size: min(23, scene.tileSize * 0.48), in: collectionLayer)
        } else if [.water, .donut, .star, .lantern].contains(p.material) {
            flyingToken(asset, at: origin, to: end, size: min(23, scene.tileSize * 0.48), parent: collectionLayer)
        }
        for i in 0..<3 {
            particles.spawn(kind, at: origin, in: collectionLayer, color: UIColor(hex: i == 0 ? p.secondary : p.tint),
                size: kind == .firefly ? 10 : 7, life: 0.42 + Double(i) * 0.04, target: end, index: i)
        }
    }

    private func objectivePulse(_ index: Int, complete: Bool) {
        guard let scene, let target = scene.headerCard?.childNode(withName: "objective:\(index)") else { return }
        if complete {
            installCompletionMarker(on: target)
            guard completedObjectives.insert(index).inserted else { return }
        }
        if !SignatureMotion.isReduced {
            target.run(.sequence([.scale(to: complete ? 1.15 : 1.08, duration: 0.08), .scale(to: 1, duration: 0.13)]), withKey: "objectiveArrival")
        }
        if complete {
            let point = scene.convert(CGPoint(x: 16, y: 0), from: target)
            particles.burst(.sparkle, at: point, in: collectionLayer, profile: .profile(for: .star), count: 7, radius: 34)
            Effects.haptic(.light, intensity: 0.5); Audio.shared.play(.tap)
        }
    }

    private func installCompletionMarker(on target: SKNode) {
        guard target.childNode(withName: "objectiveCheck") == nil else { return }
        let badge = SKShapeNode(circleOfRadius: 7)
        badge.name = "objectiveCheck"; badge.fillColor = UIColor(hex: "#2CA864")
        badge.strokeColor = UIColor(hex: "#FFF5BD"); badge.lineWidth = 1
        let iconPoint = target.children.first?.position ?? .zero
        badge.position = CGPoint(x: iconPoint.x + 8, y: -11); badge.zPosition = 10
        badge.addChild(GameSurface.label("✓", size: 10, color: .white))
        target.addChild(badge)
        target.accessibilityValue = String(localized: "Complete")
    }

    /// Build the actual earned piece at its match anchor before gravity moves it.
    /// Only decorative fragments converge; their source cells keep engine timing.
    func formSpecial(cell: Cell, at position: Pos, contributors: Set<Pos>, delay: TimeInterval) {
        guard let scene, let special = cell.special else { return }
        attach()
        let center = scene.point(forRow: position.r, col: position.c)
        for (index, p) in contributors.sorted(by: { $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r }).prefix(8).enumerated() {
            particles.spawn(special == .colorBomb ? .star : .glow,
                at: scene.point(forRow: p.r, col: p.c), in: boardLayer,
                color: UIColor(hex: "#FFF3D6"), size: scene.tileSize * 0.16,
                life: min(0.30, max(0.15, delay)), target: center, index: index)
        }
        let token = generation
        boardLayer.run(.sequence([.wait(forDuration: delay), .run { [weak self] in
            guard let self, self.generation == token, let scene = self.scene,
                  scene.grid[position.r][position.c]?.id == cell.id else { return }
            scene.refreshNode(at: position)
            self.present([.specialCreated(at: position, special: special)],
                         sources: scene.nodes[position.r][position.c].map { [position: $0] } ?? [:])
        }]))
    }

    private func destructionCopy(from source: SKNode?, at point: CGPoint, material: AnimationMaterial) -> SKNode? {
        guard material != .fruit, let source, boardLayer.children.count < 210,
              let copy = source.copy() as? SKNode else { return nil }
        copy.removeAllActions(); copy.isAccessibilityElement = false
        copy.position = point; copy.zPosition = 2
        source.alpha = 0
        boardLayer.addChild(copy)
        let release: SKAction
        switch material {
        case .firefly, .honey, .jelly, .water, .cloud, .cream:
            release = .sequence([
                .group([.scaleX(to: 1.12, duration: 0.07), .scaleY(to: 0.83, duration: 0.07)]),
                .group([.scaleX(to: 0.88, duration: 0.11), .scaleY(to: 1.18, duration: 0.11)]),
                .group([.scale(to: 0.65, duration: 0.16), .fadeOut(withDuration: 0.16)])])
        case .vine, .seaweed, .flower, .lantern, .star, .rainbow, .scarab:
            release = .group([.moveBy(x: 5, y: 18, duration: 0.35),
                .sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.23)])])
        default:
            release = .sequence([.scale(to: 1.08, duration: 0.05),
                .group([.scale(to: 0.70, duration: 0.17), .fadeOut(withDuration: 0.17)])])
        }
        copy.run(.sequence([release, .removeFromParent()]))
        return copy
    }

    @discardableResult
    func travelThroughPortals(_ transfers: [PortalPresentationTransfer], node: SKNode,
                             destination: CGPoint, delay: TimeInterval) -> TimeInterval {
        guard let scene, !transfers.isEmpty else { return 0 }
        attach()
        if SignatureMotion.isReduced {
            node.run(SignatureMotion.landingAction(to: destination, duration: 0.16, delay: 0))
            return 0.16
        }
        // A pathological authored route stays bounded while retaining its exit.
        var route = Array(transfers.prefix(3))
        if transfers.count > 3, let last = transfers.last { route.append(last) }
        var actions: [SKAction] = [.wait(forDuration: delay)]
        for (index, transfer) in route.enumerated() {
            let entry = scene.point(forRow: transfer.from.r, col: transfer.from.c)
            let exit = scene.point(forRow: transfer.to.r, col: transfer.to.c)
            actions += [.move(to: entry, duration: 0.03),
                .group([.scaleX(to: 0.40, duration: 0.035), .scaleY(to: 1.12, duration: 0.035),
                        .fadeAlpha(to: 0.20, duration: 0.035)]),
                .move(to: exit, duration: 0),
                .group([.scale(to: 1.08, duration: 0.035), .fadeIn(withDuration: 0.035)])]
            present([.portalEntered(from: transfer.from, to: transfer.to)],
                    delay: { _ in delay + Double(index) * 0.10 + 0.03 })
        }
        actions.append(SignatureMotion.landingAction(to: destination, duration: 0.12, delay: 0))
        node.run(.sequence(actions), withKey: "portalTransfer")
        return delay + Double(route.count) * 0.10 + 0.12 + SignatureMotion.landingSettleDuration
    }

    private func specialCreated(_ special: Special, at point: CGPoint, source: SKNode?) {
        guard let scene else { return }
        let art = source?.childNode(withName: "emoji")
        if !SignatureMotion.isReduced {
            art?.run(.sequence([.scale(to: 0.48, duration: 0.04), .scale(to: 1.20, duration: 0.13),
                .scale(to: 1, duration: 0.12)]), withKey: "specialForm")
        }
        switch special {
        case .colorBomb: rainbowBurst(at: point, count: 14)
        case .wrapped:
            ribbon(at: point, color: UIColor(hex: "#FFF1C9"), reach: scene.tileSize * 0.55, vertical: false)
            ribbon(at: point, color: scene.worldTheme.glowColor, reach: scene.tileSize * 0.55, vertical: true)
            particles.burst(.sparkle, at: point, in: boardLayer, profile: .profile(for: .star), count: 7, radius: scene.tileSize)
        case .stripedRow, .stripedCol:
            ribbon(at: point, color: .white, reach: scene.tileSize * 0.75, vertical: special == .stripedCol)
        case .fish: particles.burst(.bubble, at: point, in: boardLayer, profile: .profile(for: .water), count: 7, radius: scene.tileSize)
        case .rocket, .ufo: particles.burst(.smoke, at: point, in: boardLayer, profile: .profile(for: .cloud), count: 5, radius: scene.tileSize, scale: 2)
        default: particles.burst(.sparkle, at: point, in: boardLayer, profile: .profile(for: .star), count: 10, radius: scene.tileSize)
        }
        ring(at: point, color: scene.worldTheme.glowColor, radius: scene.tileSize * 0.8, duration: 0.35)
    }

    private func cascade(depth: Int) {
        guard let scene, depth >= 2, !SignatureMotion.isReduced else { return }
        let frame = scene.gameplayLayout.board
        let material: AnimationMaterial
        switch scene.worldTheme.id {
        case "firefly": material = .firefly
        case "ice": material = .ice
        case "honey": material = .honey
        case "volcano": material = .lava
        case "coral": material = .water
        case "cloud": material = .cloud
        case "golden": material = .amber
        case "sahara": material = .sandstone
        case "galaxy": material = .cosmic
        case "sakura": material = .flower
        default: material = .star
        }
        let p = WorldAnimationProfile.profile(for: material)
        for side in [-1.0, 1.0] {
            let origin = CGPoint(x: side < 0 ? frame.minX - 3 : frame.maxX + 3, y: frame.minY + frame.height * 0.35)
            particles.burst(particleKind(material), at: origin, in: boardLayer, profile: p,
                            count: min(9, depth * 2), radius: 25)
            if depth >= 4 {
                particles.spawn(.glow, at: origin, in: boardLayer, color: UIColor(hex: p.tint), size: 17,
                    life: 0.65, target: CGPoint(x: origin.x, y: frame.maxY), index: Int(side))
            }
        }
    }

    private func idleTick() {
        guard let scene, scene.canAcceptBoardInput, !SignatureMotion.isReduced, scene.view?.window != nil else { return }
        let candidates = scene.grid.enumerated().flatMap { r, row in row.enumerated().compactMap { c, cell -> (Pos, Cell)? in
            cell.map { (Pos(r: r, c: c), $0) }
        }}
        guard !candidates.isEmpty else { return }
        // Only three cells breathe at a time; no permanent tile emitters.
        for offset in 0..<min(3, candidates.count) {
            let (position, cell) = candidates[(idleCursor + offset * max(1, candidates.count / 3)) % candidates.count]
            guard let node = scene.nodes[position.r][position.c] else { continue }
            let asset = cell.blocker.map { scene.worldTheme.blockerAsset($0) }
                ?? cell.piece.map { scene.worldTheme.pieceAsset($0.color) } ?? ""
            let p = profile(asset: asset, blocker: cell.blocker?.type)
            let art = node.childNode(withName: "blockerArt") ?? node.childNode(withName: "emoji")
            if let art {
                if cell.blocker == nil, let special = cell.special {
                    WorldIdleAnimator.animate(special: special, art: art, at: node.position,
                        tile: scene.tileSize, particles: particles, parent: boardLayer)
                } else {
                    WorldIdleAnimator.animate(profile: p, art: art, at: node.position,
                        tile: scene.tileSize, particles: particles, parent: boardLayer)
                }
            }
        }
        let portals = scene.levelConfig.layout.portalPairs
        if !portals.isEmpty {
            let pair = portals[(idleCursor / 3) % portals.count]
            let position = idleCursor.isMultiple(of: 2) ? pair.from : pair.to
            WorldIdleAnimator.portal(at: scene.point(forRow: position.r, col: position.c),
                tile: scene.tileSize, particles: particles, parent: boardLayer)
        }
        idleCursor = (idleCursor + 3) % candidates.count
    }

    private func light(at point: CGPoint, color: UIColor, size: CGFloat, duration: TimeInterval) {
        guard !SignatureMotion.isReduced else { return }
        particles.spawn(.glow, at: point, in: boardLayer, color: color, size: size, life: duration)
    }

    private func ring(at point: CGPoint, color: UIColor, radius: CGFloat, duration: TimeInterval) {
        guard !SignatureMotion.isReduced, boardLayer.children.count < 210 else { return }
        let ring = SKShapeNode(circleOfRadius: radius * 0.35)
        ring.position = point; ring.strokeColor = color; ring.fillColor = .clear
        ring.lineWidth = 2; ring.glowWidth = 1.5
        boardLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.4, duration: duration), .fadeOut(withDuration: duration)]), .removeFromParent()]))
    }

    private func fracture(at point: CGPoint, color: UIColor, severity: Int) {
        guard let scene, !SignatureMotion.isReduced, boardLayer.children.count < 210 else { return }
        let path = CGMutablePath()
        let side = scene.tileSize * 0.35
        for i in 0..<min(4, severity + 1) {
            let angle = CGFloat(i) * 2.1
            path.move(to: point)
            path.addLine(to: CGPoint(x: point.x + cos(angle) * side * 0.5, y: point.y + sin(angle) * side * 0.5))
            path.addLine(to: CGPoint(x: point.x + cos(angle + 0.4) * side, y: point.y + sin(angle + 0.4) * side))
        }
        let crack = SKShapeNode(path: path); crack.strokeColor = color; crack.lineWidth = 1.4
        crack.glowWidth = 1; boardLayer.addChild(crack)
        crack.run(.sequence([.wait(forDuration: 0.1), .fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func ribbon(at point: CGPoint, color: UIColor, reach: CGFloat, vertical: Bool) {
        guard !SignatureMotion.isReduced, boardLayer.children.count < 210 else { return }
        let path = UIBezierPath(); path.move(to: CGPoint(x: -reach, y: 0))
        path.addCurve(to: CGPoint(x: reach, y: 0), controlPoint1: CGPoint(x: -reach * 0.4, y: reach * 0.5),
                      controlPoint2: CGPoint(x: reach * 0.3, y: -reach * 0.5))
        let strand = SKShapeNode(path: path.cgPath); strand.strokeColor = color
        strand.lineWidth = 3; strand.lineCap = .round; strand.glowWidth = 1
        strand.position = point; strand.zRotation = vertical ? .pi / 2 : 0
        boardLayer.addChild(strand)
        strand.run(.sequence([.group([.scaleX(to: 1.2, duration: 0.09), .scaleY(to: 0.3, duration: 0.09)]),
            .group([.scale(to: 0.15, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    private func lid(from source: SKNode?, at point: CGPoint, size: CGFloat, color: UIColor) {
        guard let texture = (source as? SKSpriteNode)?.texture, !SignatureMotion.isReduced, boardLayer.children.count < 210 else { return }
        let lid = SKSpriteNode(texture: SKTexture(rect: CGRect(x: 0.12, y: 0.72, width: 0.76, height: 0.28), in: texture))
        lid.size = CGSize(width: size * 0.65, height: size * 0.24)
        lid.position = CGPoint(x: point.x, y: point.y + size * 0.25)
        boardLayer.addChild(lid)
        lid.run(.sequence([.group([.moveBy(x: size * 0.25, y: size * 0.85, duration: 0.35),
            .rotate(byAngle: 1.1, duration: 0.35), .sequence([.wait(forDuration: 0.17), .fadeOut(withDuration: 0.18)])]), .removeFromParent()]))
    }

    private func flyingToken(_ asset: String, at point: CGPoint, to target: CGPoint, size: CGFloat, parent: SKNode? = nil) {
        guard !SignatureMotion.isReduced, collectionLayer.children.count + boardLayer.children.count < 220 else { return }
        let token = MenuStyle.art(asset, size: size)
        token.position = point; (parent ?? boardLayer).addChild(token)
        let path = UIBezierPath(); path.move(to: point)
        path.addQuadCurve(to: target, controlPoint: CGPoint(x: point.x + 32, y: max(point.y, target.y) + 25))
        token.run(.sequence([.group([.follow(path.cgPath, asOffset: false, orientToPath: false, duration: 0.55),
            .scale(to: 0.3, duration: 0.55), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.2)])]), .removeFromParent()]))
    }

    private func rainbowBurst(at point: CGPoint, count: Int) {
        for i in 0..<count {
            let angle = CGFloat(i) * 2.399963
            let color = UIColor(hex: ["#FF95DD", "#FFEC73", "#95F9CF", "#91DFFF", "#CBA7FF"][i % 5])
            particles.spawn(.star, at: point, in: boardLayer, color: color, size: 7, life: 0.45,
                velocity: CGVector(dx: cos(angle) * 95, dy: sin(angle) * 95), gravity: 70, index: i)
        }
    }
}
