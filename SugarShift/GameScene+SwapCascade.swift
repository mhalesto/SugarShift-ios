import SpriteKit

// Swap + cascade resolution
extension GameScene {
    // MARK: - Swap + cascade

    func cellSnapshot(for positions: Set<Pos>) -> [Pos: Cell] {
        var snapshot: [Pos: Cell] = [:]
        for p in positions {
            if let cell = grid[p.r][p.c] {
                snapshot[p] = cell
            }
        }
        return snapshot
    }

    func triggeredBombCount(in positions: Set<Pos>) -> Int {
        positions.reduce(0) { total, p in
            total + (grid[p.r][p.c]?.special == .bomb ? 1 : 0)
        }
    }

    func recordGoalProgress(preClear: [Pos: Cell],
                                    cleared: Set<Pos>,
                                    damaged: Set<Pos>,
                                    triggeredBombs: Int = 0) {
        if case .collectColor(let index, _) = levelConfig.goal {
            let targetColor = palette[max(0, index) % palette.count]
            let collected = cleared.filter { preClear[$0]?.color.lowercased() == targetColor.lowercased() }.count
            if collected > 0 {
                collectedGoalTiles += collected
            }
        }

        if triggeredBombs > 0 {
            detonatedBombs += triggeredBombs
        }

        if !damaged.isEmpty || !cleared.isEmpty {
            updateHUD()
        }
        showObjectiveCompleteIfNeeded()
    }

    func openChestsAfterClear(preClear: [Pos: Cell],
                                      clearResult: ClearResult) -> Set<Pos> {
        var opened = Set<Pos>()
        for p in clearResult.damagedBlockers {
            guard preClear[p]?.blocker?.type == .chest,
                  (preClear[p]?.blocker?.hits ?? 0) <= 1,
                  grid[p.r][p.c]?.blocker == nil else { continue }
            opened.insert(p)
        }

        let adjacent = Engine.openAdjacentChests(&grid,
                                                 near: clearResult.cleared.union(clearResult.damagedBlockers))
        opened.formUnion(adjacent)
        guard !opened.isEmpty else { return [] }

        openedChests += opened.count
        awardChestRewards(opened: opened)
        for p in adjacent {
            if let node = nodes[p.r][p.c] {
                showMechanicImpact(.chest, at: node.position)
            }
            refreshNode(at: p)
        }
        Analytics.track("chest_opened",
                        properties: ["level": "\(levelNumber)",
                                     "count": "\(opened.count)"])
        showObjectiveCompleteIfNeeded()
        return opened
    }

    func awardChestRewards(opened: Set<Pos>) {
        guard !opened.isEmpty else { return }
        var coins = 0
        var hammers = 0
        var swaps = 0
        var shuffles = 0
        for p in opened {
            coins += 25 + ((p.r + p.c + levelNumber) % 3) * 10
            switch (p.r + p.c + levelNumber) % 7 {
            case 0: hammers += 1
            case 1: swaps += 1
            case 2: shuffles += 1
            default: break
            }
        }
        cash += coins
        hammerCount += hammers
        swapCount += swaps
        shuffleCount += shuffles
        let center = opened.first.map { point(forRow: $0.r, col: $0.c) } ?? .zero
        Effects.showScorePopup(coins, at: center, in: self, color: UIColor(hex: "#FACC15"))
        Effects.showComboBanner(text: String(localized: "CHEST OPENED!"), color: UIColor(hex: "#FACC15"), in: self)
        rebuildShuffleChip()
    }

    func applySugarRushIfReady(to matches: Set<Pos>, depth: Int) -> Set<Pos> {
        guard depth == 1, sugarRushCharged else { return matches }
        let resolution = Engine.sugarRushResolution(in: grid,
                                                    base: matches,
                                                    preferredAnchor: turnPrimaryAnchor)
        guard let anchor = resolution.anchor else { return matches }
        sugarRushCharged = false
        cash += 15
        let center = point(forRow: anchor.r, col: anchor.c)
        Effects.showComboBanner(text: String(localized: "SUGAR RUSH!"), color: UIColor(hex: "#EC4899"), in: self)
        Effects.showScorePopup(15, at: CGPoint(x: center.x, y: center.y + tileSize * 0.5), in: self, color: UIColor(hex: "#FACC15"))
        Analytics.track("sugar_rush_used", properties: ["level": "\(levelNumber)"])
        updateComboMeter()
        return resolution.positions
    }

    func chargeSugarRushIfNeeded(depth: Int) {
        guard depth >= 3 else { return }
        chargeSugarRush(source: "cascade", depth: depth)
    }

    func chargeSugarRush(source: String, depth: Int? = nil) {
        guard !sugarRushCharged else { return }
        sugarRushCharged = true
        Effects.showComboBanner(text: String(localized: "SUGAR RUSH READY"), color: UIColor(hex: "#EC4899"), in: self)
        Audio.shared.play(.colorCharge)
        Effects.haptic(.medium, intensity: 0.72)
        updateComboMeter()
        Analytics.track("sugar_rush_charged", properties: [
            "level": "\(levelNumber)",
            "source": source,
            "depth": "\(depth ?? 0)",
            "flow": "\(flowLevel)"
        ])
    }

    func scoreForClear(preClear: [Pos: Cell],
                               clearResult: ClearResult,
                               pointsPerTile: Int,
                               multiplier: Int) -> Int {
        let base = clearResult.affectedCount * pointsPerTile * multiplier
        guard levelConfig.modifiers.contains(.bananaScoreDouble) else { return base }
        let bananaBonus = clearResult.cleared.filter { pos in
            guard let color = preClear[pos]?.color else { return false }
            return Theme.fruitIndex(forColor: color) == 4
        }.count * pointsPerTile * multiplier
        return base + bananaBonus
    }

    func objectiveImpact(preClear: [Pos: Cell], clearResult: ClearResult) -> Int {
        switch levelConfig.goal {
        case .clearBlockers:
            return clearResult.damagedBlockers.count
        case .collectColor(let index, _):
            let target = palette[max(0, index) % max(1, palette.count)].lowercased()
            return clearResult.cleared.filter {
                preClear[$0]?.color.lowercased() == target
            }.count
        case .openChests:
            return clearResult.damagedBlockers.filter {
                preClear[$0]?.blocker?.type == .chest
            }.count
        case .detonateBombs:
            return preClear.values.filter { $0.special == .bomb }.count
        case .collectIngredients, .collectKeys, .collectIngredientsAndKeys:
            let columns: [Int] = grid.flatMap { row in
                row.enumerated().compactMap { column, cell in
                    guard let cell, cell.kind != .normal else { return nil }
                    return column
                }
            }
            let dropColumns = Set(columns)
            return clearResult.cleared.filter { dropColumns.contains($0.c) }.count
        case .score, .createSpecials:
            return 0
        }
    }

    func attemptSwap(_ a: Pos, _ b: Pos) {
        guard !isResolving, movesLeft > 0 else { return }
        isResolving = true
        clearSpecialBlastPreview()
        cascadeDepth = 0
        chocolateDamagedThisTurn = false
        chainTilesCleared = 0
        chainSpecialsTriggered = 0
        chainBlockersDamaged = 0
        chainObjectiveHits = 0
        turnCreatedSpecials = 0
        turnIntent = .match
        turnScoreAtStart = score
        turnPrimaryAnchor = nil
        turnConsumesMove = false
        bossDamageAppliedThisTurn = false
        updateComboMeter()

        let result = Engine.swapIfValid(grid, a, b)
        // Snapshot the pre-swap state so the player can undo a botched move.
        // Only snapshot if the swap is actually going to take effect.
        let willCommitMove = result.didSwap ||
            specialComboActivation(a, b) != nil ||
            colorBombActivation(a, b) != nil
        if willCommitMove {
            takeUndoSnapshot()
            turnScoreAtStart = score
            turnPrimaryAnchor = b
        }
        let nodeA = nodes[a.r][a.c]
        let nodeB = nodes[b.r][b.c]
        let posA = point(forRow: a.r, col: a.c)
        let posB = point(forRow: b.r, col: b.c)
        let dur: TimeInterval = 0.15

        if let combo = specialComboActivation(a, b) {
            turnIntent = .specialCombo
            preferredSpecialSpawnPositions.removeAll()
            turnConsumesMove = true
            grid = combo.swappedGrid
            nodes[a.r][a.c] = nodeB
            nodes[b.r][b.c] = nodeA
            movesLeft -= 1
            Analytics.track("special_combo_used",
                            properties: ["level": "\(levelNumber)",
                                         "first": combo.first.rawValue,
                                         "second": combo.second.rawValue,
                                         "kind": Engine.specialComboKind(combo.first, combo.second)?.rawValue ?? "unknown"])
            Effects.haptic(.medium, intensity: 0.72)
            Audio.shared.play(.swapClick, pan: soundPan(at: posB))
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.detonateSpecialCombo(first: combo.first,
                                           second: combo.second,
                                           positions: (a, b),
                                           targetColor: combo.targetColor)
            }
        } else if let colorBomb = colorBombActivation(a, b) {
            turnIntent = .special
            preferredSpecialSpawnPositions.removeAll()
            turnConsumesMove = true
            grid = colorBomb.swappedGrid
            nodes[a.r][a.c] = nodeB
            nodes[b.r][b.c] = nodeA
            movesLeft -= 1
            Analytics.track("color_bomb_used", properties: ["level": "\(levelNumber)"])
            Effects.haptic(.medium)
            Audio.shared.play(.swapClick)
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.detonateColorBomb(at: colorBomb.bombPosition,
                                        targetColor: colorBomb.targetColor)
            }
        } else if result.didSwap {
            turnIntent = .match
            preferredSpecialSpawnPositions = [b, a]
            turnConsumesMove = true
            grid = result.grid
            nodes[a.r][a.c] = nodeB
            nodes[b.r][b.c] = nodeA
            movesLeft -= 1
            Effects.haptic(.light)
            Audio.shared.play(.swapClick)
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.resolveCascade()
            }
        } else {
            preferredSpecialSpawnPositions.removeAll()
            turnConsumesMove = false
            Effects.haptic(.soft)
            Audio.shared.play(.swapInvalid)
            nodeA?.run(.sequence([.move(to: posB, duration: dur), .move(to: posA, duration: dur)]))
            nodeB?.run(.sequence([.move(to: posA, duration: dur), .move(to: posB, duration: dur)])) { [weak self] in
                self?.isResolving = false
            }
        }
    }

    func specialComboActivation(_ a: Pos,
                                        _ b: Pos) -> (swappedGrid: Grid,
                                                      first: Special,
                                                      second: Special,
                                                      targetColor: String?,
                                                      center: Pos)? {
        guard let swap = Engine.classifySwap(grid, a, b),
              case .specialCombo(_, let first, let second, let targetColor) = swap.activation else {
            return nil
        }
        return (swap.grid, first, second, targetColor, b)
    }

    func detonateSpecialCombo(first: Special,
                                      second: Special,
                                      positions: (Pos, Pos),
                                      targetColor: String?) {
        guard let kind = Engine.specialComboKind(first, second) else {
            isResolving = false
            return
        }
        let affected = specialComboAffectedPositions(kind: kind,
                                                     first: first,
                                                     second: second,
                                                     positions: positions,
                                                     targetColor: targetColor)
        let presentation = specialComboPresentation(for: kind)
        let plan = presentationPlan(kind: kind,
                                    first: first,
                                    second: second,
                                    positions: positions,
                                    targetColor: targetColor)
        recordSpecialComboForContract(kind: kind)
        Analytics.track("special_combo_resolved",
                        properties: ["level": "\(levelNumber)",
                                     "kind": kind.rawValue,
                                     "affected": "\(affected.count)",
                                     "boss_shield": "\(bossShieldRemaining)",
                                     "smash_charge": "\(smashCharge)"])
        resolveManualClear(affected,
                           banner: presentation.0,
                           tint: presentation.1,
                           scorePerTile: 70,
                           center: point(forRow: positions.1.r, col: positions.1.c),
                           presentation: plan)
    }

    func colorBombActivation(_ a: Pos, _ b: Pos) -> (swappedGrid: Grid, bombPosition: Pos, targetColor: String)? {
        guard let swap = Engine.classifySwap(grid, a, b),
              case .colorBomb(let position, let targetColor) = swap.activation else { return nil }
        return (swap.grid, position, targetColor)
    }

    func detonateColorBomb(at pos: Pos, targetColor: String) {
        var matches = Set<Pos>()
        matches.insert(pos)
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c]?.color == targetColor {
                matches.insert(Pos(r: r, c: c))
            }
        }
        matches = Engine.expandMatchesWithSpecials(grid,
                                                   matches,
                                                   bigger: specialBlastIsExpanded,
                                                   excludingSpecialsAt: [pos])
        let colorTargets = matches.sorted {
            if $0.r != $1.r { return $0.r < $1.r }
            return $0.c < $1.c
        }
        let plan = ClearPresentationPlan(kind: .colorBomb,
                                         origin: pos,
                                         secondary: nil,
                                         firstSpecial: .colorBomb,
                                         secondSpecial: nil,
                                         fishTargets: [],
                                         colorTargets: colorTargets)
        resolveManualClear(matches,
                           banner: "COLOR BLAST!",
                           tint: UIColor(hex: "#FACC15"),
                           scorePerTile: 40,
                           center: point(forRow: pos.r, col: pos.c),
                           presentation: plan)
    }

    func resolveManualClear(_ matches: Set<Pos>,
                                    banner: String,
                                    tint: UIColor,
                                    scorePerTile: Int,
                                    center: CGPoint,
                                    presentation: ClearPresentationPlan? = nil) {
        let resolvedMatches = turnConsumesMove
            ? applySugarRushIfReady(to: matches, depth: 1)
            : matches
        let preClear = cellSnapshot(for: resolvedMatches)
        let triggeredBombs = triggeredBombCount(in: resolvedMatches)
        let specialsInChain = preClear.values.reduce(into: 0) { $0 += ($1.special != nil ? 1 : 0) }
        let clearResult = Engine.clearMatches(&grid, matches: resolvedMatches)
        let affected = max(1, clearResult.affectedCount)
        totalCascadeClears += affected
        if affected >= 8 {
            maxCascadeDepth = max(maxCascadeDepth, 2)
        }
        let chargeMultiplier: Double
        switch presentation?.kind {
        case .some(.combo):       chargeMultiplier = 1.30
        case .some(.colorBomb):   chargeMultiplier = 1.18
        // Spending Smash must not immediately manufacture more Smash meter.
        // Any unspent charge now comes from deliberately choosing a lower tier.
        case .some(.playerSmash): chargeMultiplier = 0
        case .none:               chargeMultiplier = 1.0
        }
        recordChainProgress(tilesCleared: clearResult.cleared.count,
                            blockersDamaged: clearResult.damagedBlockers.count,
                            specialsTriggered: specialsInChain,
                            chargeMultiplier: chargeMultiplier,
                            objectiveHits: objectiveImpact(preClear: preClear,
                                                           clearResult: clearResult))
        recordGoalProgress(preClear: preClear,
                           cleared: clearResult.cleared,
                           damaged: clearResult.damagedBlockers,
                           triggeredBombs: triggeredBombs)
        _ = openChestsAfterClear(preClear: preClear,
                                  clearResult: clearResult)

        if let presentation {
            playClearPresentation(presentation, tint: tint)
        }
        Audio.shared.play(.fruitBreak, pan: soundPan(at: center))

        for p in clearResult.cleared {
            guard let n = nodes[p.r][p.c] else { continue }
            let impactDelay = presentation?.delay(for: p) ?? 0
            let burstTint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
            let impactPosition = n.position
            let fruitTexture = (n.childNode(withName: "emoji") as? SKSpriteNode)?.texture
            n.run(.sequence([
                .wait(forDuration: impactDelay),
                .group([.scaleX(to: 1.07, duration: 0.035),
                        .scaleY(to: 0.90, duration: 0.035)]),
                .run { [weak self] in
                    guard let self else { return }
                    let burst = Effects.makeTileBurst(tint: burstTint)
                    burst.position = impactPosition
                    self.worldNode.addChild(burst)
                    burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
                    let fragments = Effects.makeFruitFragmentBurst(
                        texture: fruitTexture,
                        tint: burstTint,
                        count: presentation?.isMajor == true ? 6 : 4,
                        size: presentation?.isMajor == true ? 18 : 15)
                    fragments.position = impactPosition
                    self.worldNode.addChild(fragments)
                },
                .group([.scale(to: 1.38, duration: 0.11),
                        .fadeOut(withDuration: 0.14)]),
                .removeFromParent()
            ]))
            nodes[p.r][p.c] = nil
        }

        for p in clearResult.damagedBlockers {
            guard let n = nodes[p.r][p.c] else { continue }
            let impactDelay = presentation?.delay(for: p) ?? 0
            let impactPosition = n.position
            let blockerType = preClear[p]?.blocker?.type
            let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
            n.run(.sequence([
                .wait(forDuration: impactDelay),
                .run { [weak self] in
                    guard let self else { return }
                    if let blockerType {
                        self.showMechanicImpact(blockerType, at: impactPosition)
                    }
                    let flash = Effects.makeImpactFlash(at: impactPosition, big: false)
                    self.worldNode.addChild(flash)
                    let chunks = Effects.makeChunkBurst(tint: tint, count: 5, size: 13)
                    chunks.position = impactPosition
                    chunks.zPosition = 735
                    self.worldNode.addChild(chunks)
                },
                .scale(to: 1.08, duration: 0.06),
                .scale(to: 1.0, duration: 0.10),
                .run { [weak self] in self?.refreshNode(at: p) }
            ]))
        }

        if presentation == nil {
            let flash = Effects.makeImpactFlash(at: center, big: true)
            worldNode.addChild(flash)
        }
        Effects.showComboBanner(text: banner, color: tint, in: self)
        let comboPoints = scoreForClear(preClear: preClear,
                                        clearResult: clearResult,
                                        pointsPerTile: scorePerTile,
                                        multiplier: 1)
        Effects.showScorePopup(comboPoints,
                               at: center,
                               in: self,
                               color: tint)
        score += comboPoints
        feedPiggyBank(scoreEarned: comboPoints)
        showObjectiveCompleteIfNeeded()
        Effects.shake(worldNode,
                      intensity: presentation?.isMajor == true ? 12 : min(8, CGFloat(affected) * 0.55),
                      duration: presentation?.isMajor == true ? 0.34 : 0.24)
        let presentationDelay = presentation?.maximumDelay(in: resolvedMatches) ?? 0
        run(.wait(forDuration: max(0.24, presentationDelay + 0.20))) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    func resolveCascade() {
        let groups = Engine.findMatchGroups(grid)
        let squares = Engine.findSquares(grid)
        guard !(groups.isEmpty && squares.isEmpty) else {
            finishCascadeTurn()
            return
        }

        cascadeDepth += 1
        let depth = cascadeDepth
        maxCascadeDepth = max(maxCascadeDepth, depth)

        // Build the full cleared set (groups + special detonations)
        var matches = Set<Pos>()
        for g in groups { matches.formUnion(g) }
        matches = Engine.expandMatchesWithSpecials(grid,
                                                   matches,
                                                   bigger: specialBlastIsExpanded)
        matches = applySugarRushIfReady(to: matches, depth: depth)
        // A 2x2 square clears like a match (and spawns a Fish below).
        for sq in squares { for p in sq { matches.insert(p) } }
        // Each activated fish also seeks a deterministic goal/blocker tile.
        matches = addingObjectiveFishTargets(to: matches)

        // Fish from a square outranks a plain striped; otherwise use the run spawn.
        let eligibleSpawnPositions = Set(matches.filter { p in
            guard let cell = grid[p.r][p.c] else { return false }
            return cell.blocker == nil && cell.kind == .normal
        })
        var effectiveSpawn = Engine.specialSpawn(
            from: groups,
            bombRunLength: levelConfig.bombSpawnRunLength,
            preferredPositions: depth == 1 ? preferredSpecialSpawnPositions : [],
            eligiblePositions: eligibleSpawnPositions)
        if let square = squares.first,
           effectiveSpawn == nil
            || effectiveSpawn?.special == .stripedRow
            || effectiveSpawn?.special == .stripedCol {
            let preferred = depth == 1
                ? preferredSpecialSpawnPositions.first(where: square.contains)
                : nil
            effectiveSpawn = SpecialSpawn(position: preferred ?? square[0], special: .fish)
        }
        let specialSpawn = effectiveSpawn
        let specialSpawnColor = specialSpawn.flatMap { grid[$0.position.r][$0.position.c]?.color }

        let preClear = cellSnapshot(for: matches)
        let triggeredBombs = triggeredBombCount(in: matches)
        let clearResult = Engine.clearMatches(&grid, matches: matches)
        let cleared = clearResult.affectedCount
        guard cleared > 0 else {
            finishCascadeTurn()
            return
        }
        totalCascadeClears += cleared
        let specialsInChain = preClear.values.reduce(into: 0) { $0 += ($1.special != nil ? 1 : 0) }
        let cascadeCredit = turnIntent == .playerSmash ? 0 : (depth == 1 ? 1.0 : 0.50)
        recordChainProgress(tilesCleared: clearResult.cleared.count,
                            blockersDamaged: clearResult.damagedBlockers.count,
                            specialsTriggered: specialsInChain,
                            chargeMultiplier: cascadeCredit,
                            objectiveHits: objectiveImpact(preClear: preClear,
                                                           clearResult: clearResult))
        recordGoalProgress(preClear: preClear,
                           cleared: clearResult.cleared,
                           damaged: clearResult.damagedBlockers,
                           triggeredBombs: triggeredBombs)
        _ = openChestsAfterClear(preClear: preClear,
                                  clearResult: clearResult)
        let multiplier = depth
        let pointsPerTile = 10

        // Compute centroid of cleared positions in scene coords
        var sx: CGFloat = 0
        var sy: CGFloat = 0
        for p in matches {
            let pt = point(forRow: p.r, col: p.c)
            sx += pt.x
            sy += pt.y
        }
        let centroid = CGPoint(x: sx / CGFloat(cleared), y: sy / CGFloat(cleared))

        // Animate clear + spawn per-tile bursts
        let clearGroup = SKAction.sequence([
            .group([.scaleX(to: 1.06, duration: 0.035),
                    .scaleY(to: 0.90, duration: 0.035)]),
            .group([.scale(to: 1.25, duration: 0.10),
                    .fadeOut(withDuration: 0.15)])
        ])

        let feedback = TurnFeedbackPolicy.feedback(depth: depth, cleared: cleared)
        let isBigSmash = feedback.tier >= .big
        playTriggeredSpecialEffects(preClear: preClear)
        Audio.shared.play(.fruitBreak, pan: soundPan(at: centroid))

        var nodesToRemove: [SKNode] = []
        for p in clearResult.cleared {
            if let n = nodes[p.r][p.c] {
                nodesToRemove.append(n)
                nodes[p.r][p.c] = nil

                // Tile-color particle burst at this tile
                let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
                let particleCount: Int
                switch feedback.tier {
                case .match: particleCount = 6
                case .nice: particleCount = 8
                case .big: particleCount = 10
                case .huge, .epic: particleCount = 12
                }
                let burst = Effects.makeTileBurst(tint: tint, count: particleCount)
                burst.position = n.position
                worldNode.addChild(burst)
                burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))

                let fruitTexture = (n.childNode(withName: "emoji") as? SKSpriteNode)?.texture
                let fragmentCount = feedback.tier >= .huge ? 6 : (isBigSmash ? 5 : 3)
                let fragments = Effects.makeFruitFragmentBurst(texture: fruitTexture,
                                                                tint: tint,
                                                                count: fragmentCount,
                                                                size: isBigSmash ? 17 : 13)
                fragments.position = n.position
                fragments.zPosition = 735
                worldNode.addChild(fragments)
            }
        }
        for p in clearResult.damagedBlockers {
            guard let n = nodes[p.r][p.c] else { continue }
            let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
            if let type = preClear[p]?.blocker?.type {
                showMechanicImpact(type, at: n.position)
                if type == .chocolate { chocolateDamagedThisTurn = true }
            }
            let flash = Effects.makeImpactFlash(at: n.position, big: false)
            worldNode.addChild(flash)
            let shards = Effects.makeShardBurst(tint: tint, count: 4, size: 12)
            shards.position = n.position
            shards.zPosition = 705
            worldNode.addChild(shards)
            shards.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
            let chunks = Effects.makeChunkBurst(tint: tint, count: 5, size: 13)
            chunks.position = n.position
            chunks.zPosition = 735
            worldNode.addChild(chunks)
            n.run(.sequence([
                .scale(to: 1.08, duration: 0.06),
                .scale(to: 1.0, duration: 0.10),
                .run { [weak self] in self?.refreshNode(at: p) }
            ]))
        }

        // Bright flash + shockwave + star sparkles at the cluster centroid
        let flash = Effects.makeImpactFlash(at: centroid, big: isBigSmash)
        worldNode.addChild(flash)

        if feedback.tier >= .nice {
            let sparkleCount = feedback.tier >= .huge ? 8 : (isBigSmash ? 6 : 4)
            let sparkles = Effects.makeStarSparkle(count: sparkleCount)
            sparkles.position = centroid
            sparkles.zPosition = 745
            worldNode.addChild(sparkles)
        }

        // Score popup at centroid
        let added = scoreForClear(preClear: preClear,
                                  clearResult: clearResult,
                                  pointsPerTile: pointsPerTile,
                                  multiplier: multiplier)
        score += added
        feedPiggyBank(scoreEarned: added)
        awardCascadeCoinBonus(depth: depth, cleared: cleared, at: centroid)
        showObjectiveCompleteIfNeeded()
        chargeSugarRushIfNeeded(depth: depth)
        // Depth increments once per step, so this fires once per chain.
        if depth == 3 { DailyMissions.record([.chainReaction]) }
        let popupColor: UIColor = depth >= 2 ? UIColor(hex: "#FACC15") : .white
        Effects.showScorePopup(added, at: centroid, in: self, color: popupColor)

        // Celebration channels are tiered by TurnFeedbackPolicy so each one
        // (banner → beam → shake → confetti) is rarer than the last.
        // Combo banner (depth 2+) takes priority over the big-clear phrase.
        if feedback.showsBanner, let combo = Effects.comboPhrase(forDepth: depth) {
            Effects.showComboBanner(text: combo.text, color: combo.color, in: self)
            Audio.shared.play(.combo(depth: depth))
        } else if feedback.showsBanner, let big = Effects.bigClearPhrase(forCount: cleared) {
            Effects.showComboBanner(text: big.text, color: big.color, in: self)
            Audio.shared.play(.match)
        } else {
            Audio.shared.play(.match)
        }

        switch feedback.haptic {
        case .light:   Effects.haptic(.light)
        case .medium:  Effects.haptic(.medium)
        case .success: Effects.notify(.success)
        }

        if feedback.spawnsConfetti {
            spawnConfetti()
        }

        if let shake = feedback.shakeIntensity {
            Effects.shake(worldNode, intensity: CGFloat(shake), duration: 0.28)
        }

        // Spawn the earned special tile at the centre/intersection of the match.
        if let spawn = specialSpawn, clearResult.cleared.contains(spawn.position) {
            let color = specialSpawnColor ?? palette.randomElement(using: &gameplayRNG) ?? palette[0]
            grid[spawn.position.r][spawn.position.c] = Cell(id: "special-\(gameplayRNG.next())",
                                                            color: color,
                                                            special: spawn.special,
                                                            kind: .normal)
            Analytics.track("special_created",
                            properties: ["level": "\(levelNumber)",
                                         "special": spawn.special.rawValue])
            createdSpecials += 1
            turnCreatedSpecials += 1
            if depth == 1, preferredSpecialSpawnPositions.contains(spawn.position) {
                addSmashCharge(8, source: "intentional_special")
            }
            DailyMissions.record([.specialsCreated(1)])
            showSpecialHint(spawn.special)
        }

        let removeAction = SKAction.sequence([clearGroup, .removeFromParent()])
        for n in nodesToRemove { n.run(removeAction) }

        run(.wait(forDuration: 0.18)) { [weak self] in
            guard let self else { return }
            if clearResult.cleared.isEmpty {
                self.finishCascadeTurn()
            } else {
                self.applyCollapseAndRefill()
            }
        }
    }

    func finishCascadeTurn() {
        if turnConsumesMove,
           !bossDamageAppliedThisTurn,
           chainSpecialsTriggered > 0 || cascadeDepth >= 3 {
            damageBossShield(by: 1, source: cascadeDepth >= 3 ? "deep_cascade" : "special_chain")
            bossDamageAppliedThisTurn = true
        }
        if turnConsumesMove {
            finishTurnMastery()
        }
        // End of the player's turn: chocolate gets one chance to spread,
        // but only if we didn't damage one this turn (adjacency rule).
        applyChocolateSpreadIfDue()
        tickSyrupIfNeeded()
        tickCountdownFusesIfNeeded()
        tickBossPressureIfNeeded()
        if !isLevelGoalComplete, movesLeft > 0, !Engine.hasAnyMoves(grid) {
            autoReshuffleNoMoves()
            return
        }
        preferredSpecialSpawnPositions.removeAll()
        dropMercySpecialIfStruggling()
        isResolving = false
        if turnConsumesMove {
            Analytics.track("turn_combo_summary",
                            properties: ["level": "\(levelNumber)",
                                         "tiles": "\(chainTilesCleared)",
                                         "specials": "\(chainSpecialsTriggered)",
                                         "blockers": "\(chainBlockersDamaged)",
                                         "objective_hits": "\(chainObjectiveHits)",
                                         "cascade_depth": "\(cascadeDepth)",
                                         "smash_charge": "\(smashCharge)",
                                         "flow": "\(flowLevel)",
                                         "intent": turnIntent.rawValue,
                                         "sugar_rush_ready": "\(sugarRushCharged)"])
        }
        maybeShowComboNudge()
        checkLevelEnd()
        scheduleIdleHint()
        turnConsumesMove = false
        bossDamageAppliedThisTurn = false
        turnPrimaryAnchor = nil
    }

    /// One-time teaching: the first time two power-ups sit orthogonally adjacent,
    /// nudge the player to swap them into a combo. Self-gated by showTeachingToast.
    func maybeShowComboNudge() {
        guard !levelEnded else { return }
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c]?.special != nil {
                let adjacentSpecial =
                    (c + 1 < cols && grid[r][c + 1]?.special != nil) ||
                    (r + 1 < rows && grid[r + 1][c]?.special != nil)
                if adjacentSpecial {
                    showTeachingToast(key: "combo_adjacency",
                                      text: String(localized: "Two power-ups touching? Swap them for a giant combo!"))
                    return
                }
            }
        }
    }

    /// Anti-frustration that is earned rather than random: after repeated losses,
    /// one visibly announced special appears on a genuinely tight finish. Shared
    /// daily/tower boards remain untouched and the assist can fire only once.
    func dropMercySpecialIfStruggling() {
        guard !levelEnded,
              !isLevelGoalComplete,
              !isDailyChallengeRun,
              towerRun == nil,
              !mercySpecialGrantedThisAttempt,
              (1...2).contains(movesLeft),
              primaryGoalProgressFraction < 0.88 else { return }
        let failures = Analytics.levelStats(for: levelNumber)["fails"] ?? 0
        guard failures >= 2 else { return }
        let hasSpecial = grid.contains { row in row.contains { $0?.special != nil } }
        guard !hasSpecial else { return }
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c], cell.blocker == nil,
                      cell.kind == .normal, cell.special == nil else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        func priority(_ position: Pos) -> Int {
            var value = position.r
            let neighbors = [Pos(r: position.r - 1, c: position.c),
                             Pos(r: position.r + 1, c: position.c),
                             Pos(r: position.r, c: position.c - 1),
                             Pos(r: position.r, c: position.c + 1)]
                .filter { $0.r >= 0 && $0.r < rows && $0.c >= 0 && $0.c < cols }
            value += neighbors.filter { grid[$0.r][$0.c]?.blocker != nil }.count * 100
            if case .collectColor(let index, _) = levelConfig.goal {
                let target = palette[max(0, index) % max(1, palette.count)]
                if grid[position.r][position.c]?.color == target { value += 70 }
            }
            return value
        }
        candidates.sort {
            let lhs = priority($0), rhs = priority($1)
            if lhs != rhs { return lhs > rhs }
            if $0.r != $1.r { return $0.r > $1.r }
            return $0.c < $1.c
        }
        guard let p = candidates.first else { return }
        let granted: Special
        switch levelConfig.goal {
        case .clearBlockers, .openChests:
            granted = .wrapped
        case .collectIngredients, .collectKeys, .collectIngredientsAndKeys:
            granted = .stripedCol
        default:
            granted = .stripedRow
        }
        mercySpecialGrantedThisAttempt = true
        grid[p.r][p.c]?.special = granted
        refreshNode(at: p)
        nodes[p.r][p.c]?.run(.sequence([.scale(to: 1.2, duration: 0.12),
                                        .scale(to: 1.0, duration: 0.14)]))
        Effects.showComboBanner(text: String(localized: "SECOND WIND!"),
                                color: UIColor(hex: "#34D399"), in: self)
        Effects.haptic(.medium, intensity: 0.68)
        Analytics.track("mercy_special_granted",
                        properties: ["level": "\(levelNumber)",
                                     "failures": "\(failures)",
                                     "progress": "\(primaryGoalProgressFraction)",
                                     "special": granted.rawValue])
    }

    var primaryGoalProgressFraction: Double {
        switch levelConfig.goal {
        case .score:
            return min(1, Double(score) / Double(max(1, scoreTarget)))
        case .clearBlockers:
            return min(1, 1 - Double(remainingBlockerCount()) / Double(max(1, startingBlockers)))
        case .collectColor(_, let count):
            return min(1, Double(collectedGoalTiles) / Double(max(1, count)))
        case .createSpecials(let count):
            return min(1, Double(createdSpecials) / Double(max(1, count)))
        case .detonateBombs(let count):
            return min(1, Double(detonatedBombs) / Double(max(1, count)))
        case .collectIngredients(let count):
            return min(1, Double(collectedIngredients) / Double(max(1, count)))
        case .collectKeys(let count):
            return min(1, Double(collectedKeys) / Double(max(1, count)))
        case .openChests(let count):
            return min(1, Double(openedChests) / Double(max(1, count)))
        case .collectIngredientsAndKeys(let ingredients, let keys):
            let ingredientProgress = Double(collectedIngredients) / Double(max(1, ingredients))
            let keyProgress = Double(collectedKeys) / Double(max(1, keys))
            return min(1, (ingredientProgress + keyProgress) / 2)
        }
    }

}
