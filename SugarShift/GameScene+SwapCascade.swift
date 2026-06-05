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
        guard depth == 1, sugarRushCharged, let anchor = matches.first else { return matches }
        sugarRushCharged = false
        var boosted = matches
        for c in 0..<cols where grid[anchor.r][c] != nil {
            boosted.insert(Pos(r: anchor.r, c: c))
        }
        for r in 0..<rows where grid[r][anchor.c] != nil {
            boosted.insert(Pos(r: r, c: anchor.c))
        }
        cash += 15
        let center = point(forRow: anchor.r, col: anchor.c)
        Effects.showComboBanner(text: String(localized: "SUGAR RUSH!"), color: UIColor(hex: "#EC4899"), in: self)
        Effects.showScorePopup(15, at: CGPoint(x: center.x, y: center.y + tileSize * 0.5), in: self, color: UIColor(hex: "#FACC15"))
        Analytics.track("sugar_rush_used", properties: ["level": "\(levelNumber)"])
        return boosted
    }

    func chargeSugarRushIfNeeded(depth: Int) {
        guard depth >= 3, !sugarRushCharged else { return }
        sugarRushCharged = true
        Effects.showComboBanner(text: String(localized: "SUGAR RUSH READY"), color: UIColor(hex: "#EC4899"), in: self)
        Analytics.track("sugar_rush_charged", properties: ["level": "\(levelNumber)",
                                                           "depth": "\(depth)"])
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

    func attemptSwap(_ a: Pos, _ b: Pos) {
        guard !isResolving, movesLeft > 0 else { return }
        isResolving = true
        cascadeDepth = 0
        chocolateDamagedThisTurn = false
        chainTilesCleared = 0
        chainSpecialsTriggered = 0
        chainBlockersDamaged = 0
        lastChainTierFired = 0
        sugarRushCharged = false
        updateComboMeter()

        let result = Engine.swapIfValid(grid, a, b)
        // Snapshot the pre-swap state so the player can undo a botched move.
        // Only snapshot if the swap is actually going to take effect.
        let willCommitMove = result.didSwap ||
            specialComboActivation(a, b) != nil ||
            colorBombActivation(a, b) != nil
        if willCommitMove {
            takeUndoSnapshot()
        }
        let nodeA = nodes[a.r][a.c]
        let nodeB = nodes[b.r][b.c]
        let posA = point(forRow: a.r, col: a.c)
        let posB = point(forRow: b.r, col: b.c)
        let dur: TimeInterval = 0.15

        if let combo = specialComboActivation(a, b) {
            grid = combo.swappedGrid
            nodes[a.r][a.c] = nodeB
            nodes[b.r][b.c] = nodeA
            movesLeft -= 1
            Analytics.track("special_combo_used",
                            properties: ["level": "\(levelNumber)",
                                         "first": combo.first.rawValue,
                                         "second": combo.second.rawValue])
            Effects.haptic(.heavy)
            Audio.shared.play(.bomb)
            nodeA?.run(.move(to: posB, duration: dur))
            nodeB?.run(.move(to: posA, duration: dur)) { [weak self] in
                self?.detonateSpecialCombo(first: combo.first,
                                           second: combo.second,
                                           positions: (a, b),
                                           targetColor: combo.targetColor)
            }
        } else if let colorBomb = colorBombActivation(a, b) {
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
        guard let cellA = grid[a.r][a.c],
              let cellB = grid[b.r][b.c],
              let specialA = cellA.special,
              let specialB = cellB.special else { return nil }

        var swapped = grid
        swapped[a.r][a.c] = cellB
        swapped[b.r][b.c] = cellA

        let targetColor: String?
        if specialA == .colorBomb {
            targetColor = cellB.color
        } else if specialB == .colorBomb {
            targetColor = cellA.color
        } else {
            targetColor = nil
        }

        return (swapped, specialA, specialB, targetColor, b)
    }

    func detonateSpecialCombo(first: Special,
                                      second: Special,
                                      positions: (Pos, Pos),
                                      targetColor: String?) {
        let pair = Set([first, second])
        var affected = Set<Pos>()
        let center = positions.1

        func add(_ r: Int, _ c: Int) {
            if r >= 0, r < rows, c >= 0, c < cols, grid[r][c] != nil {
                affected.insert(Pos(r: r, c: c))
            }
        }

        func addRow(_ r: Int) {
            for c in 0..<cols { add(r, c) }
        }

        func addCol(_ c: Int) {
            for r in 0..<rows { add(r, c) }
        }

        func addSquare(around p: Pos, radius: Int) {
            for dr in -radius...radius {
                for dc in -radius...radius {
                    add(p.r + dr, p.c + dc)
                }
            }
        }

        func matchingColorPositions(_ color: String?) -> [Pos] {
            guard let color else { return [] }
            var out: [Pos] = []
            for r in 0..<rows {
                for c in 0..<cols where grid[r][c]?.color == color {
                    out.append(Pos(r: r, c: c))
                }
            }
            return out
        }

        let banner: String
        let tint: UIColor

        if first == .colorBomb && second == .colorBomb {
            // Two color bombs together wipe the whole board — the signature
            // "clear everything" move players expect from match-3.
            for r in 0..<rows { for c in 0..<cols { add(r, c) } }
            banner = String(localized: "BOARD CLEAR!")
            tint = UIColor(hex: "#F472B6")
        } else if pair == Set([.stripedRow, .stripedCol]) ||
            (first.rawValue.hasPrefix("striped") && second.rawValue.hasPrefix("striped")) {
            addRow(positions.0.r)
            addCol(positions.1.c)
            addRow(positions.1.r)
            addCol(positions.0.c)
            banner = "DOUBLE STRIPE!"
            tint = UIColor(hex: "#60A5FA")
        } else if (first == .wrapped && (second == .stripedRow || second == .stripedCol)) ||
                    (second == .wrapped && (first == .stripedRow || first == .stripedCol)) {
            for offset in -1...1 {
                addRow(center.r + offset)
                addCol(center.c + offset)
            }
            banner = "WRAPPED STRIPE!"
            tint = UIColor(hex: "#F97316")
        } else if pair.contains(.colorBomb), pair.contains(.stripedRow) || pair.contains(.stripedCol) {
            for (index, p) in matchingColorPositions(targetColor).enumerated() {
                index.isMultiple(of: 2) ? addRow(p.r) : addCol(p.c)
            }
            banner = "RAINBOW STRIPES!"
            tint = UIColor(hex: "#A78BFA")
        } else if pair.contains(.colorBomb), pair.contains(.wrapped) {
            for p in matchingColorPositions(targetColor) {
                addSquare(around: p, radius: 1)
            }
            banner = "RAINBOW WRAP!"
            tint = UIColor(hex: "#F472B6")
        } else if pair.contains(.colorBomb), pair.contains(.bomb) {
            for p in matchingColorPositions(targetColor) {
                addSquare(around: p, radius: 1)
            }
            banner = "RAINBOW BOOM!"
            tint = UIColor(hex: "#FACC15")
        } else if first == .bomb && second == .bomb {
            addSquare(around: center, radius: 2)
            banner = "MEGA BOOM!"
            tint = UIColor(hex: "#EF4444")
        } else if first == .wrapped && second == .wrapped {
            // Two wrapped candies detonate as a pair of large blasts.
            addSquare(around: positions.0, radius: 2)
            addSquare(around: positions.1, radius: 2)
            banner = String(localized: "DOUBLE WRAP!")
            tint = UIColor(hex: "#FB923C")
        } else {
            addSquare(around: center, radius: 1)
            banner = "SPECIAL COMBO!"
            tint = UIColor(hex: "#10B981")
        }

        affected.insert(positions.0)
        affected.insert(positions.1)
        affected = Engine.expandMatchesWithSpecials(grid,
                                                    affected,
                                                    bigger: specialBlastIsExpanded)
        resolveManualClear(affected,
                           banner: banner,
                           tint: tint,
                           scorePerTile: 70,
                           center: point(forRow: center.r, col: center.c))
    }

    func colorBombActivation(_ a: Pos, _ b: Pos) -> (swappedGrid: Grid, bombPosition: Pos, targetColor: String)? {
        guard let cellA = grid[a.r][a.c], let cellB = grid[b.r][b.c] else { return nil }
        guard cellA.special == .colorBomb || cellB.special == .colorBomb else { return nil }

        var swapped = grid
        swapped[a.r][a.c] = cellB
        swapped[b.r][b.c] = cellA

        if cellA.special == .colorBomb {
            return (swapped, b, cellB.color)
        } else {
            return (swapped, a, cellA.color)
        }
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
                                                   bigger: specialBlastIsExpanded)
        resolveManualClear(matches,
                           banner: "COLOR BLAST!",
                           tint: UIColor(hex: "#FACC15"),
                           scorePerTile: 40,
                           center: point(forRow: pos.r, col: pos.c))
    }

    func resolveManualClear(_ matches: Set<Pos>,
                                    banner: String,
                                    tint: UIColor,
                                    scorePerTile: Int,
                                    center: CGPoint) {
        let preClear = cellSnapshot(for: matches)
        let triggeredBombs = triggeredBombCount(in: matches)
        let specialsInChain = preClear.values.reduce(into: 0) { $0 += ($1.special != nil ? 1 : 0) }
        let clearResult = Engine.clearMatches(&grid, matches: matches)
        let affected = max(1, clearResult.affectedCount)
        totalCascadeClears += affected
        if affected >= 8 {
            maxCascadeDepth = max(maxCascadeDepth, 2)
        }
        recordChainProgress(tilesCleared: clearResult.cleared.count,
                            blockersDamaged: clearResult.damagedBlockers.count,
                            specialsTriggered: specialsInChain)
        recordGoalProgress(preClear: preClear,
                           cleared: clearResult.cleared,
                           damaged: clearResult.damagedBlockers,
                           triggeredBombs: triggeredBombs)
        _ = openChestsAfterClear(preClear: preClear,
                                  clearResult: clearResult)

        for p in clearResult.cleared {
            guard let n = nodes[p.r][p.c] else { continue }
            let burstTint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
            let burst = Effects.makeTileBurst(tint: burstTint)
            burst.position = n.position
            worldNode.addChild(burst)
            burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
            n.run(.sequence([
                .group([.scale(to: 1.5, duration: 0.12),
                        .fadeOut(withDuration: 0.18)]),
                .removeFromParent()
            ]))
            nodes[p.r][p.c] = nil
        }

        for p in clearResult.damagedBlockers {
            guard let n = nodes[p.r][p.c] else { continue }
            if let type = preClear[p]?.blocker?.type {
                showMechanicImpact(type, at: n.position)
            }
            let flash = Effects.makeImpactFlash(at: n.position, big: false)
            worldNode.addChild(flash)
            let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
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

        let flash = Effects.makeImpactFlash(at: center, big: true)
        worldNode.addChild(flash)
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
        Effects.shake(worldNode, intensity: affected >= 12 ? 14 : 9, duration: 0.32)
        run(.wait(forDuration: 0.28)) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    func resolveCascade() {
        let groups = Engine.findMatchGroups(grid)
        guard !groups.isEmpty else {
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

        let specialSpawn = Engine.specialSpawn(from: groups,
                                               bombRunLength: levelConfig.bombSpawnRunLength)
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
        recordChainProgress(tilesCleared: clearResult.cleared.count,
                            blockersDamaged: clearResult.damagedBlockers.count,
                            specialsTriggered: specialsInChain)
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
        let clearGroup = SKAction.group([
            .scale(to: 1.25, duration: 0.08),
            .fadeOut(withDuration: 0.16)
        ])

        // Crank effects up for the first few levels so the user gets that
        // "ooh, satisfying" hit right out of the gate.
        let earlyBoost = levelNumber <= 5
        let isBigSmash = cleared >= 4 || depth >= 2 || earlyBoost

        var nodesToRemove: [SKNode] = []
        for p in clearResult.cleared {
            if let n = nodes[p.r][p.c] {
                nodesToRemove.append(n)
                nodes[p.r][p.c] = nil

                // Tile-color particle burst at this tile
                let tint = UIColor(hex: (n.userData?["color"] as? String) ?? "#FFFFFF")
                let burst = Effects.makeTileBurst(tint: tint)
                burst.position = n.position
                worldNode.addChild(burst)
                burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))

                // Colored shards "cracking" the candy
                let shardCount = earlyBoost ? 9 : (isBigSmash ? 8 : 6)
                let shardSize: CGFloat = earlyBoost ? 22 : 18
                let shards = Effects.makeShardBurst(tint: tint,
                                                     count: shardCount,
                                                     size: shardSize)
                shards.position = n.position
                shards.zPosition = 705
                worldNode.addChild(shards)
                shards.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
                if isBigSmash {
                    let chunks = Effects.makeChunkBurst(tint: tint,
                                                        count: earlyBoost ? 7 : 5,
                                                        size: earlyBoost ? 18 : 14)
                    chunks.position = n.position
                    chunks.zPosition = 735
                    worldNode.addChild(chunks)
                }
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

        let sparkleCount = earlyBoost ? 14 : (isBigSmash ? 10 : 7)
        let sparkles = Effects.makeStarSparkle(count: sparkleCount)
        sparkles.position = centroid
        sparkles.zPosition = 745
        worldNode.addChild(sparkles)

        // Vertical "candy beam" through the cluster column for combos / big clears.
        // Picks the column closest to the centroid and lights it up like a
        // striped-candy detonation.
        if depth >= 2 || cleared >= 5 {
            let beamCol = matches.first?.c ?? 0
            let beamX = point(forRow: 0, col: beamCol).x
            let beam = Effects.makeColumnBeam(x: beamX, fromY: -size.height / 2,
                                               toY: size.height / 2,
                                               tint: UIColor(hex: "#F472B6"))
            worldNode.addChild(beam)
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
        let popupColor: UIColor = depth >= 2 ? UIColor(hex: "#FACC15") : .white
        Effects.showScorePopup(added, at: centroid, in: self, color: popupColor)

        // Banner: combo (depth 2+) takes priority, else big-clear (4+ tiles)
        if let combo = Effects.comboPhrase(forDepth: depth) {
            Effects.showComboBanner(text: combo.text, color: combo.color, in: self)
            Effects.notify(.success)
            Audio.shared.play(.combo(depth: depth))
        } else if let big = Effects.bigClearPhrase(forCount: cleared) {
            Effects.showComboBanner(text: big.text, color: big.color, in: self)
            Effects.haptic(.medium)
            Audio.shared.play(.match)
        } else {
            Effects.haptic(.medium)
            Audio.shared.play(.match)
        }

        // Confetti for big chains or massive single clears
        if depth >= 3 || cleared >= 6 {
            spawnConfetti()
        }

        // Screen shake for sizable clears
        if cleared >= 4 || depth >= 2 {
            Effects.shake(worldNode,
                          intensity: cleared >= 6 ? 12 : 7,
                          duration: 0.28)
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
        // End of the player's turn: chocolate gets one chance to spread,
        // but only if we didn't damage one this turn (adjacency rule).
        applyChocolateSpreadIfDue()
        tickSyrupIfNeeded()
        tickCountdownFusesIfNeeded()
        if !isLevelGoalComplete, movesLeft > 0, !Engine.hasAnyMoves(grid) {
            autoReshuffleNoMoves()
            return
        }
        grantComboFreeSpecialIfCharged()
        isResolving = false
        maybeShowComboNudge()
        checkLevelEnd()
        scheduleIdleHint()
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

    /// Mechanical payoff for a max-tier cascade chain: plant a free special on the
    /// board so big combos reward momentum with a tool, not just a banner. Granted
    /// at most once per swap chain (gated by `sugarRushCharged`).
    func grantComboFreeSpecialIfCharged() {
        guard !levelEnded,
              !sugarRushCharged,
              lastChainTierFired >= GameScene.comboTiers.count else { return }
        sugarRushCharged = true
        var candidates: [Pos] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = grid[r][c], cell.blocker == nil,
                      cell.kind == .normal, cell.special == nil else { continue }
                candidates.append(Pos(r: r, c: c))
            }
        }
        guard let p = candidates.randomElement(using: &gameplayRNG) else { return }
        grid[p.r][p.c]?.special = Bool.random(using: &gameplayRNG) ? .wrapped : .bomb
        refreshNode(at: p)
        nodes[p.r][p.c]?.run(.sequence([.scale(to: 1.2, duration: 0.12),
                                        .scale(to: 1.0, duration: 0.16)]))
        Effects.showComboBanner(text: String(localized: "FREE SPECIAL!"),
                                color: UIColor(hex: "#A855F7"), in: self)
        Effects.notify(.success)
    }
}
