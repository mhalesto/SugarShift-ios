import SpriteKit

// Boosters: +Moves selector, handlers, mode visuals, execution
extension GameScene {
    // MARK: - +Moves quantity selector

    func showQuantityPopup() {
        hideQuantityPopup()
        guard let circle = movesBoosterCircle else { return }

        // Convert the circle's position into scene coords (it lives inside footerCard)
        let circleScenePos = circle.parent?.convert(circle.position, to: self) ?? circle.position

        let popupW: CGFloat = 240
        let popupH: CGFloat = 86
        let popupY = circleScenePos.y + 78

        let popup = SKNode()
        popup.position = CGPoint(x: circleScenePos.x, y: popupY)
        popup.zPosition = 1000
        popup.alpha = 0
        popup.setScale(0.4)

        // Card background
        let bg = SKShapeNode(rectOf: CGSize(width: popupW, height: popupH), cornerRadius: 16)
        bg.fillColor = UIColor(white: 1, alpha: 0.97)
        bg.strokeColor = UIColor(white: 0, alpha: 0.08)
        bg.lineWidth = 1
        bg.zPosition = 0
        popup.addChild(bg)

        // Drop shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: popupW, height: popupH), cornerRadius: 16)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        popup.addChild(shadow)

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = String(localized: "Buy moves")
        title.fontSize = 11
        title.fontColor = UIColor(hex: "#475569")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: popupH / 2 - 16)
        popup.addChild(title)

        // Options as small dotted pills
        let pillW: CGFloat = 36
        let pillH: CGFloat = 30
        let spacing: CGFloat = 8
        let totalW = CGFloat(quantityOptions.count) * pillW + CGFloat(quantityOptions.count - 1) * spacing
        var x = -totalW / 2 + pillW / 2

        for opt in quantityOptions {
            let isSelected = opt == movesQuantity
            let pill = SKShapeNode(rectOf: CGSize(width: pillW, height: pillH), cornerRadius: 9)
            pill.fillColor = isSelected ? UIColor(hex: "#F472B6") : UIColor(white: 0, alpha: 0.05)
            pill.strokeColor = isSelected ? .clear : UIColor(white: 0, alpha: 0.12)
            pill.lineWidth = 1
            pill.position = CGPoint(x: x, y: -10)
            pill.name = "qty:\(opt)"
            popup.addChild(pill)

            let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            l.text = "\(opt)"
            l.fontSize = 14
            l.fontColor = isSelected ? .white : UIColor(hex: "#0F172A")
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            pill.addChild(l)

            x += pillW + spacing
        }

        // Pointer (small triangle pointing down at the badge) — drawn as a rotated square
        let pointer = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
        pointer.fillColor = UIColor(white: 1, alpha: 0.97)
        pointer.strokeColor = .clear
        pointer.position = CGPoint(x: 0, y: -popupH / 2 + 4)
        pointer.zRotation = .pi / 4
        pointer.zPosition = -1
        popup.addChild(pointer)

        addChild(popup)
        quantityPopup = popup

        popup.run(.group([
            .scale(to: 1.0, duration: 0.18),
            .fadeIn(withDuration: 0.12)
        ]))
    }

    func hideQuantityPopup() {
        guard let popup = quantityPopup else { return }
        quantityPopup = nil
        popup.run(.sequence([
            .group([
                .scale(to: 0.4, duration: 0.12),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ]))
    }

    func selectQuantity(_ q: Int) {
        movesQuantity = q
        rebuildHUD()
        updateHUD()
        movesQuantityBadgeLabel?.text = "+\(q)"
        // little pop on the badge to confirm the change
        movesQuantityBadge?.run(.sequence([
            .scale(to: 1.25, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ]))
        Effects.haptic(.light)
    }

    func buyMoves() {
        guard cash >= movesBuyCost else {
            Effects.haptic(.soft)
            // Briefly shake the cash pill to signal "not enough"
            if let pill = footerCard?.children.first(where: { ($0 as? SKShapeNode)?.fillColor == UIColor(white: 1, alpha: 0.97) }) {
                Effects.shake(pill, intensity: 4, duration: 0.2)
            }
            return
        }
        cash -= movesBuyCost
        movesLeft += movesQuantity
        boosterUsedThisAttempt = true
        Analytics.track("coin_spend",
                        properties: ["item": "moves",
                                     "coins": "\(movesBuyCost)",
                                     "quantity": "\(movesQuantity)",
                                     "level": "\(levelNumber)"])
        Analytics.track("booster_use",
                        properties: ["type": "moves",
                                     "quantity": "\(movesQuantity)",
                                     "source": "coins",
                                     "level": "\(levelNumber)"])
        Effects.haptic(.medium)
        Effects.notify(.success)

        // Floating "+N moves" feedback above the booster
        if let circle = movesBoosterCircle {
            let pos = circle.parent?.convert(circle.position, to: self) ?? .zero
            Effects.showScorePopup(movesQuantity,
                                   at: CGPoint(x: pos.x, y: pos.y + 36),
                                   in: self,
                                   color: UIColor(hex: "#F472B6"))
        }

        // Bounce the booster circle
        movesBoosterCircle?.run(.sequence([
            .scale(to: 1.18, duration: 0.1),
            .scale(to: 1.0, duration: 0.14)
        ]))
    }

    // MARK: - Booster handlers

    func handleBoosterTap(_ label: String) {
        if levelConfig.modifiers.contains(.noBoosters) {
            showStatusToast("Boosters are locked on this level.")
            Effects.haptic(.soft)
            Effects.notify(.warning)
            return
        }
        if smashTargeting { cancelPlayerSmashTargeting() }
        // If already in a mode and the same booster is tapped again, cancel.
        if (label == "Hammer" && boosterMode == .hammer) ||
           (label == "Swap"   && boosterMode == .swap) {
            cancelBoosterMode()
            return
        }
        cancelBoosterMode()

        switch label {
        case "Hammer":  tryUseHammer()
        case "Swap":    tryUseSwap()
        case "Shuffle": tryUseShuffle()
        case "+Moves":  buyMoves()
        case "Life":    tryUseLife()
        default: break
        }
    }

    func tryUseHammer() {
        // Use a stocked hammer for free if you own one; otherwise pay cash.
        if hammerCount == 0, cash < hammerCost { insufficientCashFeedback(); return }
        boosterMode = .hammer
        showBoosterHint(hammerCount > 0 ? "Tap a fruit to smash! (\(hammerCount) left)"
                                         : "Tap a fruit to smash!")
        highlightActiveBooster("Hammer")
        Effects.haptic(.light)
    }

    func tryUseSwap() {
        if swapCount == 0, cash < swapCost { insufficientCashFeedback(); return }
        boosterMode = .swap
        swapFirstPick = nil
        swapFirstNode = nil
        showBoosterHint(swapCount > 0 ? "Pick two fruits (\(swapCount) left)"
                                       : String(localized: "Pick two fruits to swap"))
        highlightActiveBooster("Swap")
        Effects.haptic(.light)
    }

    func tryUseShuffle() {
        guard shuffleCount > 0 else {
            insufficientCashFeedback()
            return
        }
        shuffleCount -= 1
        boosterUsedThisAttempt = true
        Analytics.track("booster_use",
                        properties: ["type": "shuffle",
                                     "source": "stock",
                                     "level": "\(levelNumber)"])
        rebuildShuffleChip()
        performShuffle(ensureMove: true)
        Effects.haptic(.medium)
        Effects.notify(.success)
    }

    func tryUseLife() {
        guard cash >= lifeCost else { insufficientCashFeedback(); return }
        cash -= lifeCost
        lives = min(livesMax, lives + 1)
        Analytics.track("coin_spend",
                        properties: ["item": "life",
                                     "coins": "\(lifeCost)",
                                     "level": "\(levelNumber)"])
        Effects.haptic(.medium)
        Effects.notify(.success)
        if let circle = boosterCircles["Life"] {
            let pos = circle.parent?.convert(circle.position, to: self) ?? .zero
            Effects.showScorePopup(1,
                                   at: CGPoint(x: pos.x, y: pos.y + 36),
                                   in: self,
                                   color: UIColor(hex: "#EF4444"))
            circle.run(.sequence([.scale(to: 1.18, duration: 0.1), .scale(to: 1.0, duration: 0.14)]))
        }
        updateHUD()
    }

    // MARK: - Booster mode visuals

    func showBoosterHint(_ text: String) {
        boosterHintLabel?.removeFromParent()
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 600
        label.alpha = 0
        label.position = CGPoint(x: 0, y: 0)

        let bg = SKShapeNode(rectOf: CGSize(width: 240, height: 36), cornerRadius: 18)
        bg.fillColor = UIColor(white: 0, alpha: 0.7)
        bg.strokeColor = UIColor.white.withAlphaComponent(0.5)
        bg.lineWidth = 1
        bg.zPosition = 599
        bg.alpha = 0
        bg.position = CGPoint(x: 0, y: 0)

        addChild(bg)
        addChild(label)
        bg.run(.fadeIn(withDuration: 0.18))
        label.run(.fadeIn(withDuration: 0.18))
        boosterHintLabel = label
        bg.name = "boosterHintBg"
    }

    func hideBoosterHint() {
        boosterHintLabel?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        boosterHintLabel = nil
        childNode(withName: "boosterHintBg")?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }

    func highlightActiveBooster(_ label: String) {
        for (k, c) in boosterCircles {
            c.removeAction(forKey: "boosterPulse")
            c.setScale(1.0)
            if k == label {
                c.run(.repeatForever(.sequence([
                    .scale(to: 1.15, duration: 0.4),
                    .scale(to: 1.0, duration: 0.4)
                ])), withKey: "boosterPulse")
            }
        }
    }

    func cancelBoosterMode() {
        boosterMode = .none
        swapFirstPick = nil
        if let n = swapFirstNode, let body = n.childNode(withName: "body") as? SKShapeNode {
            body.removeAction(forKey: "swapPulse")
            body.setScale(1.0)
            body.strokeColor = skin.tileBorder
            body.lineWidth = 1
        }
        swapFirstNode = nil
        hideBoosterHint()
        for c in boosterCircles.values {
            c.removeAction(forKey: "boosterPulse")
            c.setScale(1.0)
        }
    }

    // MARK: - Booster execution on tile

    func executeBoosterOnTile(_ pos: Pos) {
        switch boosterMode {
        case .hammer:
            performHammer(at: pos)
        case .swap:
            performSwapPick(pos)
        case .none:
            break
        }
    }

    func performHammer(at pos: Pos) {
        guard let node = nodes[pos.r][pos.c] else { return }
        let preClear = cellSnapshot(for: Set([pos]))
        // Spend a stocked hammer first; fall back to cash.
        let source = hammerCount > 0 ? "stock" : "coins"
        if hammerCount > 0 { hammerCount -= 1 } else { cash -= hammerCost }
        boosterUsedThisAttempt = true
        Analytics.track("booster_use",
                        properties: ["type": "hammer",
                                     "source": source,
                                     "level": "\(levelNumber)"])
        cancelBoosterMode()
        Audio.shared.play(.bomb)

        // Hammering a BOMB = chain detonation (3×3 area + lightning + flash + shake)
        if grid[pos.r][pos.c]?.special == .bomb {
            detonateBomb(at: pos, tappedNode: node)
            return
        }

        // Regular tile hammer — single-tile pop
        Effects.haptic(.heavy)
        let tint = UIColor(hex: (node.userData?["color"] as? String) ?? "#FFFFFF")
        let burst = Effects.makeTileBurst(tint: tint)
        burst.position = node.position
        worldNode.addChild(burst)
        burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
        let chunks = Effects.makeChunkBurst(tint: tint, count: 8, size: 17)
        chunks.position = node.position
        chunks.zPosition = 735
        worldNode.addChild(chunks)

        node.run(.sequence([
            .group([.scale(to: 1.4, duration: 0.1), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
        nodes[pos.r][pos.c] = nil
        grid[pos.r][pos.c] = nil
        recordGoalProgress(preClear: preClear,
                           cleared: Set([pos]),
                           damaged: Set())
        if preClear[pos]?.blocker?.type == .chest {
            openedChests += 1
            awardChestRewards(opened: Set([pos]))
        }

        Effects.shake(worldNode, intensity: 6, duration: 0.18)

        isResolving = true
        run(.wait(forDuration: 0.2)) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    /// Big showpiece bomb detonation when the player smashes a bomb tile with
    /// the hammer: lightning radiating outward, blast ring, screen shake,
    /// staggered tile clears in the 3×3 area, big "BOOM!" banner + score popup.
    func detonateBomb(at pos: Pos, tappedNode bombNode: SKNode) {
        Effects.haptic(.heavy)
        Effects.notify(.success)

        let bombScenePos = bombNode.position

        // 1. Lightning bolts radiating outward from the bomb in 8 directions
        for i in 0..<8 {
            let angle = CGFloat(i) * (.pi * 2 / 8)
            let bolt = Effects.makeLightningBolt(angle: angle, length: 220)
            bolt.position = bombScenePos
            bolt.zPosition = 800
            worldNode.addChild(bolt)
        }

        // 2. Blast ring + bright flash
        let blast = Effects.makeBombBlast(at: bombScenePos)
        worldNode.addChild(blast)

        let flash = Effects.makeImpactFlash(at: bombScenePos, big: true)
        worldNode.addChild(flash)

        // 3. Heavy screen shake
        Effects.shake(worldNode, intensity: 14, duration: 0.4)

        // 4. Burst the bomb tile itself with extra shards
        let bombTint = UIColor(hex: "#1F2937")
        let shards = Effects.makeShardBurst(tint: bombTint, count: 14, size: 26)
        shards.position = bombScenePos
        shards.zPosition = 740
        worldNode.addChild(shards)
        shards.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
        let chunks = Effects.makeChunkBurst(tint: UIColor(hex: "#F97316"),
                                            count: 16,
                                            size: 28,
                                            gravity: -420)
        chunks.position = bombScenePos
        chunks.zPosition = 750
        worldNode.addChild(chunks)

        bombNode.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.10),
                    .rotate(byAngle: .pi / 4, duration: 0.10)]),
            .group([.scale(to: 0.2, duration: 0.18),
                    .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
        nodes[pos.r][pos.c] = nil
        grid[pos.r][pos.c] = nil

        // 5. Collect every tile in the blast area
        var affected: [Pos] = []
        let radius = specialBlastIsExpanded ? 2 : 1
        for dr in -radius...radius {
            for dc in -radius...radius {
                let r = pos.r + dr, c = pos.c + dc
                if r >= 0, r < rows, c >= 0, c < cols, nodes[r][c] != nil {
                    affected.append(Pos(r: r, c: c))
                }
            }
        }
        let affectedSet = Set(affected)
        let preClear = cellSnapshot(for: affectedSet)
        recordGoalProgress(preClear: preClear,
                           cleared: affectedSet,
                           damaged: Set(),
                           triggeredBombs: 1)
        let opened = Set(affectedSet.filter { preClear[$0]?.blocker?.type == .chest })
        if !opened.isEmpty {
            openedChests += opened.count
            awardChestRewards(opened: opened)
        }

        // 6. Stagger the tile clears outward so the explosion feels like it
        // *spreads* rather than removing everything in one frame.
        let perTilePoints = 60
        let bombBonus = 250
        var totalAdded = bombBonus
        for (i, p) in affected.enumerated() {
            let delay = TimeInterval(i) * 0.04
            let tileNode = nodes[p.r][p.c]
            let tileColor: String = (tileNode?.userData?["color"] as? String) ?? "#FFFFFF"

            run(.wait(forDuration: delay)) { [weak self] in
                guard let self = self else { return }
                guard let n = self.nodes[p.r][p.c] else { return }
                let tint = UIColor(hex: tileColor)

                // Color burst + shards on each cleared tile
                let burst = Effects.makeTileBurst(tint: tint)
                burst.position = n.position
                self.worldNode.addChild(burst)
                burst.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))

                let s = Effects.makeShardBurst(tint: tint, count: 8, size: 20)
                s.position = n.position
                s.zPosition = 705
                self.worldNode.addChild(s)
                s.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
                let chunks = Effects.makeChunkBurst(tint: tint, count: 5, size: 14)
                chunks.position = n.position
                chunks.zPosition = 735
                self.worldNode.addChild(chunks)

                n.run(.sequence([
                    .group([.scale(to: 1.5, duration: 0.10),
                            .fadeOut(withDuration: 0.18)]),
                    .removeFromParent()
                ]))
                self.nodes[p.r][p.c] = nil
                self.grid[p.r][p.c] = nil
            }
            totalAdded += perTilePoints
        }

        // 7. Big "BOOM!" banner and total score popup at the bomb's position
        Effects.showComboBanner(text: String(localized: "BOOM!"),
                                 color: UIColor(hex: "#F97316"),
                                 in: self)
        Effects.showScorePopup(totalAdded,
                                at: bombScenePos,
                                in: self,
                                color: UIColor(hex: "#FBBF24"))
        score += totalAdded

        // 8. Cascade in once the staggered clears finish
        let totalDelay = TimeInterval(affected.count) * 0.04 + 0.25
        isResolving = true
        run(.wait(forDuration: totalDelay)) { [weak self] in
            self?.applyCollapseAndRefill()
        }
    }

    func performSwapPick(_ pos: Pos) {
        if let first = swapFirstPick {
            // Force-swap regardless of validity. Stocked swap first; else cash.
            let source = swapCount > 0 ? "stock" : "coins"
            if swapCount > 0 { swapCount -= 1 } else { cash -= swapCost }
            boosterUsedThisAttempt = true
            Analytics.track("booster_use",
                            properties: ["type": "swap",
                                         "source": source,
                                         "level": "\(levelNumber)"])
            let nodeA = nodes[first.r][first.c]
            let nodeB = nodes[pos.r][pos.c]
            let posA = point(forRow: first.r, col: first.c)
            let posB = point(forRow: pos.r, col: pos.c)

            // Swap in grid
            let tmp = grid[first.r][first.c]
            grid[first.r][first.c] = grid[pos.r][pos.c]
            grid[pos.r][pos.c] = tmp
            nodes[first.r][first.c] = nodeB
            nodes[pos.r][pos.c] = nodeA

            cancelBoosterMode()
            isResolving = true
            Effects.haptic(.medium)
            nodeA?.run(.move(to: posB, duration: 0.2))
            nodeB?.run(.move(to: posA, duration: 0.2)) { [weak self] in
                self?.cascadeDepth = 0
                self?.resolveCascade()
            }
        } else {
            // First pick — highlight and wait for second
            swapFirstPick = pos
            swapFirstNode = nodes[pos.r][pos.c]
            if let body = swapFirstNode?.childNode(withName: "body") as? SKShapeNode {
                body.strokeColor = UIColor(hex: "#FACC15")
                body.lineWidth = 4
                body.run(.repeatForever(.sequence([
                    .scale(to: 1.08, duration: 0.25),
                    .scale(to: 1.0, duration: 0.25)
                ])), withKey: "swapPulse")
            }
            Effects.haptic(.light)
        }
    }

    func performShuffle(ensureMove: Bool = false) {
        var positions: [Pos] = []
        var cells: [Cell] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if let cell = grid[r][c], cell.blocker == nil, cell.special == nil {
                    positions.append(Pos(r: r, c: c))
                    cells.append(cell)
                }
            }
        }
        guard !positions.isEmpty else { return }
        var best = grid
        for attempt in 0..<30 {
            var candidate = grid
            let shuffled = cells.shuffled(using: &gameplayRNG)
            for (i, p) in positions.enumerated() {
                let source = shuffled[i]
                candidate[p.r][p.c]?.color = source.color
                candidate[p.r][p.c]?.special = source.special
                candidate[p.r][p.c]?.kind = source.kind
            }
            best = candidate
            if !ensureMove || Engine.hasAnyMoves(candidate) || attempt == 29 { break }
        }
        grid = best
        rebuildAllNodes()
    }

    func autoReshuffleNoMoves() {
        isResolving = true
        let earlyHelp = levelNumber <= 20
        if earlyHelp { freeStuckReshufflesThisLevel += 1 }
        performShuffle(ensureMove: true)
        showStatusToast(earlyHelp ? "No good moves, reshuffling" : "No moves left on board, reshuffling")
        Effects.showComboBanner(text: earlyHelp ? "FREE SHUFFLE!" : "RESHUFFLE!",
                                color: UIColor(hex: "#60A5FA"),
                                in: self)
        Analytics.track("auto_reshuffle",
                        properties: ["level": "\(levelNumber)",
                                     "free": earlyHelp ? "true" : "false",
                                     "count": "\(freeStuckReshufflesThisLevel)"])
        run(.wait(forDuration: 0.45)) { [weak self] in
            self?.resolveCascade()
        }
    }

    func refreshNode(at pos: Pos) {
        nodes[pos.r][pos.c]?.removeFromParent()
        guard let cell = grid[pos.r][pos.c] else {
            nodes[pos.r][pos.c] = nil
            return
        }
        let node = makeTileNode(for: cell)
        node.position = point(forRow: pos.r, col: pos.c)
        worldNode.addChild(node)
        nodes[pos.r][pos.c] = node
    }

    func rebuildShuffleChip() {
        // Rebuild the footer card so the shuffle chip count refreshes
        rebuildHUD()
        updateHUD()
    }

    func insufficientCashFeedback() {
        Effects.haptic(.soft)
        Effects.notify(.warning)
        // Brief shake of the cash pill
        if let footer = footerCard {
            for child in footer.children where child is SKShapeNode {
                if let s = child as? SKShapeNode, s.frame.width > 100, s.frame.height < 50 {
                    Effects.shake(s, intensity: 4, duration: 0.2)
                    break
                }
            }
        }
        offerRewardedCoinsIfUseful()
    }

    func offerRewardedCoinsIfUseful() {
        guard Monetization.rewardedAdsAvailable,
              !coinPromptShownThisAttempt,
              shopCard == nil,
              modalCard == nil,
              endLevelCard == nil else { return }
        coinPromptShownThisAttempt = true
        showModal(title: String(localized: "Need coins?"),
                  message: "Watch one ad for \(Monetization.rewardedAdCoins) coins.",
                  primary: Monetization.rewardedAdButtonText) { [weak self] in
            self?.grantRewardedAdCoins()
        }
    }
}
