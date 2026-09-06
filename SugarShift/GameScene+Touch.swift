import SpriteKit

// Touch handling + pre-swap ghost preview
extension GameScene {
    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // Any interaction clears a lingering idle hint so arrows never stack up.
        cancelIdleHint()

        // Tower interstitials (perk draft / run over) sit above everything.
        if towerOverlay != nil {
            handleTowerOverlayTap(at: p)
            return
        }

        // 0. End-level card takes precedence
        if let card = endLevelCard {
            _ = card.handleTap(at: p)
            return
        }

        // 0.25 Shop card
        if let card = shopCard {
            _ = card.handleTap(at: p)
            return
        }

        // 0.3 Settings card
        if let card = settingsCard {
            _ = card.handleTouchBegan(at: p, timestamp: t.timestamp)
            return
        }

        if levelTesterOverlay != nil {
            handleLevelTesterTap(at: p)
            return
        }

        if preLevelPerkOverlay != nil {
            handlePreLevelPerkTap(at: p)
            return
        }

        // 0.5 Modal card (legacy stubs) — tap outside dismisses
        if let modal = modalCard {
            let local = modal.convert(p, from: self)
            var hit: SKNode? = modal.atPoint(local)
            while let h = hit {
                if h.name == "modalAction" {
                    dismissModal()  // fires primary action
                    return
                }
                if h.name == "modalClose" || h.name == "modalScrim" {
                    modalPrimaryAction = nil
                    dismissModal()
                    return
                }
                hit = h.parent
            }
            return
        }

        // 1. Quantity popup is open — handle option pick or dismiss
        if let popup = quantityPopup {
            let local = popup.convert(p, from: self)
            for child in popup.children {
                guard let name = child.name, name.hasPrefix("qty:"),
                      child.contains(local) else { continue }
                let qStr = String(name.dropFirst(4))
                if let q = Int(qStr) { selectQuantity(q) }
                hideQuantityPopup()
                return
            }
            // tap outside popup → dismiss
            hideQuantityPopup()
            return
        }

        // 2. Walk the node tree for HUD targets (booster / settings / cart / badge)
        var node: SKNode? = atPoint(p)
        while let n = node {
            if n.name == "mapButton" {
                if canAcceptBoardInput { confirmReturnToMap() }
                return
            }
            if n.name == "playButton" {
                if canAcceptBoardInput {
                    cancelBoosterMode()
                    showGuidedMoveHint(delay: 0, reason: "play_navigation")
                }
                return
            }
            if n.name == "movesQuantityBadge" {
                showQuantityPopup()
                Effects.haptic(.light)
                return
            }
            if n.name == "settingsButton" {
                if canAcceptBoardInput { openSettings() }
                return
            }
            if n.name == "cartButton" {
                if canAcceptBoardInput { openShop() }
                return
            }
            if n.name == "undoButton" {
                if undoSnapshot != nil, !levelEnded {
                    performUndo()
                } else {
                    Effects.haptic(.soft)
                }
                return
            }
            if n.name == "levelTesterButton" {
                showLevelTesterOverlay()
                Effects.haptic(.light)
                return
            }
            if n.name == "smashMeterButton" {
                handleSmashMeterTap()
                return
            }
            if let name = n.name, name.hasPrefix("booster:") {
                let label = String(name.dropFirst("booster:".count))
                handleBoosterTap(label)
                return
            }
            node = n.parent
        }

        guard canAcceptBoardInput else { return }

        if smashTargeting,
           let pos = cellAt(p),
           grid[pos.r][pos.c]?.kind == .normal {
            if smashPreviewTarget == pos {
                activatePlayerSmash(at: pos)
            } else {
                showPlayerSmashPreview(at: pos)
            }
            return
        }

        // 3. Booster mode active — next tile tap consumes it
        if boosterMode != .none, let pos = cellAt(p), grid[pos.r][pos.c] != nil {
            executeBoosterOnTile(pos)
            return
        }

        // 3. Tile interaction
        guard let pos = cellAt(p), grid[pos.r][pos.c]?.hasPiece == true,
              grid[pos.r][pos.c]?.isMovementBlocked == false else { return }
        dragStartPoint = p
        cancelIdleHint()

        if let first = firstSelection {
            if first == pos {
                deselect()
                return
            }
            if isAdjacent(first, pos) {
                attemptSwap(first, pos)
                deselect()
            } else {
                deselect()
                select(pos)
            }
        } else {
            select(pos)
            Effects.haptic(.light)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard, let t = touches.first {
            _ = card.handleTouchMoved(at: t.location(in: self), timestamp: t.timestamp)
            return
        }

        guard canAcceptBoardInput, let t = touches.first, let start = dragStartPoint, let first = firstSelection else { return }
        let p = t.location(in: self)
        let dx = p.x - start.x
        let dy = p.y - start.y
        let distance = hypot(dx, dy)
        let commitThreshold = tileSize * 0.4
        let previewThreshold = tileSize * 0.18

        // Compute the candidate target whenever the drag has any direction.
        var target = first
        if abs(dx) > abs(dy) {
            target = Pos(r: first.r, c: first.c + (dx > 0 ? 1 : -1))
        } else {
            target = Pos(r: first.r + (dy < 0 ? 1 : -1), c: first.c)
        }
        let targetInBounds = target.r >= 0 && target.r < rows && target.c >= 0 && target.c < cols && grid[target.r][target.c] != nil

        if distance > commitThreshold {
            clearGhostPreview()
            if targetInBounds {
                attemptSwap(first, target)
            }
            deselect()
            dragStartPoint = nil
            return
        }

        if Persistence.ghostPreview, distance > previewThreshold, targetInBounds {
            if ghostTarget != target {
                clearGhostPreview()
                showGhostPreview(from: first, to: target)
                ghostTarget = target
            }
        } else if distance <= previewThreshold {
            clearGhostPreview()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard, let t = touches.first {
            _ = card.handleTouchEnded(at: t.location(in: self), timestamp: t.timestamp)
            return
        }

        clearGhostPreview()
        dragStartPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let card = settingsCard {
            card.handleTouchCancelled()
            return
        }
        clearGhostPreview()
        dragStartPoint = nil
    }

    // MARK: - Pre-swap ghost preview

    /// First-tap confirmation for a manual Smash. The player sees the exact
    /// footprint and tactical value before committing a move or meter charge.
    func showPlayerSmashPreview(at target: Pos) {
        guard smashTargeting,
              let tier = selectedSmashTier ?? PlayerSmashTier.tier(for: smashCharge),
              let analysis = TacticalSmashEvaluator.analysis(
                tier: tier,
                centeredAt: target,
                in: grid,
                config: levelConfig,
                sugarRushCharged: sugarRushCharged) else { return }
        clearPlayerSmashPreview()
        smashPreviewTarget = target

        for position in analysis.affected {
            let outline = SKShapeNode(
                rectOf: CGSize(width: tileSize * 0.92, height: tileSize * 0.92),
                cornerRadius: tileSize * 0.22)
            let color: UIColor
            if analysis.hazardPositions.contains(position) {
                color = UIColor(hex: "#FB923C")
            } else if analysis.objectivePositions.contains(position) {
                color = UIColor(hex: "#34D399")
            } else if sugarRushCharged {
                color = UIColor(hex: "#EC4899")
            } else {
                color = UIColor(hex: "#A855F7")
            }
            outline.fillColor = color.withAlphaComponent(position == target ? 0.30 : 0.16)
            outline.strokeColor = color.withAlphaComponent(0.95)
            outline.lineWidth = position == target ? 3 : 2
            outline.glowWidth = position == target ? 5 : 2
            outline.position = point(forRow: position.r, col: position.c)
            outline.zPosition = 735
            outline.alpha = 0
            worldNode.addChild(outline)
            outline.run(.fadeIn(withDuration: 0.09))
            if position == target {
                outline.run(.repeatForever(.sequence([
                    .scale(to: 1.08, duration: 0.42),
                    .scale(to: 1.0, duration: 0.42)
                ])))
            }
            smashPreviewNodes.append(outline)
        }

        let detail: String
        if !analysis.objectivePositions.isEmpty {
            detail = String(localized: "OBJECTIVE +\(analysis.objectivePositions.count)")
        } else if !analysis.hazardPositions.isEmpty {
            detail = analysis.hazardPositions.count == 1
                ? String(localized: "DEFUSES HAZARD")
                : String(localized: "HAZARDS +\(analysis.hazardPositions.count)")
        } else {
            detail = String(localized: "CLEARS \(analysis.affected.count)")
        }
        let text = tier.compactTitle + " • " + detail + " • "
            + String(localized: "TAP AGAIN TO SMASH")
        let badge = SKShapeNode(
            rectOf: CGSize(width: min(size.width - 28, max(190, CGFloat(text.count) * 6.2)),
                           height: 30),
            cornerRadius: 15)
        badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.94)
        badge.strokeColor = UIColor(hex: "#C084FC")
        badge.lineWidth = 1.4
        let targetPoint = point(forRow: target.r, col: target.c)
        let verticalOffset = target.r <= 1 ? -tileSize * 0.72 : tileSize * 0.72
        badge.position = CGPoint(x: 0, y: targetPoint.y + verticalOffset)
        badge.zPosition = 760
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 9.5
        label.fontColor = UIColor(hex: "#F3E8FF")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
        worldNode.addChild(badge)
        badge.alpha = 0
        badge.run(.fadeIn(withDuration: 0.10))
        smashPreviewNodes.append(badge)

        updateComboMeter()
        Effects.haptic(.light)
        UIAccessibility.post(notification: .announcement, argument: text)
        Analytics.track("smash_target_previewed",
                        properties: ["level": "\(levelNumber)",
                                     "tier": tier.rawValue,
                                     "row": "\(target.r)",
                                     "column": "\(target.c)",
                                     "affected": "\(analysis.affected.count)",
                                     "objectives": "\(analysis.objectivePositions.count)",
                                     "hazards": "\(analysis.hazardPositions.count)"])
    }

    func clearPlayerSmashPreview() {
        for node in smashPreviewNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        smashPreviewNodes.removeAll()
        smashPreviewTarget = nil
    }

    /// Renders a faded outline on every tile that *would clear* if the player
    /// released the drag right now. Activating an existing special is treated
    /// as a successful preview too. No-op when the swap wouldn't match.
    func showGhostPreview(from a: Pos, to b: Pos) {
        guard grid[b.r][b.c] != nil else { return }
        guard let analysis = TacticalMoveEvaluator.analysis(
            for: a, b,
            in: grid,
            config: levelConfig,
            sugarRushCharged: sugarRushCharged) else { return }
        let clears = analysis.affected
        guard !clears.isEmpty else { return }

        for p in clears {
            let pt = point(forRow: p.r, col: p.c)
            let outline = SKShapeNode(rectOf: CGSize(width: tileSize * 0.92,
                                                     height: tileSize * 0.92),
                                       cornerRadius: tileSize * 0.22)
            let highlight: UIColor
            if analysis.hazardPositions.contains(p) {
                highlight = UIColor(hex: "#FB923C")
            } else if analysis.objectivePositions.contains(p) {
                highlight = UIColor(hex: "#34D399")
            } else if sugarRushCharged {
                highlight = UIColor(hex: "#EC4899")
            } else {
                highlight = UIColor(hex: "#FACC15")
            }
            outline.fillColor = highlight.withAlphaComponent(0.18)
            outline.strokeColor = highlight.withAlphaComponent(0.92)
            outline.lineWidth = 2
            outline.glowWidth = 2
            outline.position = pt
            outline.zPosition = 720
            outline.alpha = 0
            worldNode.addChild(outline)
            outline.run(.fadeAlpha(to: 1.0, duration: 0.10))
            outline.run(.repeatForever(.sequence([
                .scale(to: 1.05, duration: 0.5),
                .scale(to: 1.0,  duration: 0.5)
            ])))
            ghostNodes.append(outline)
        }

        let points = clears.map { point(forRow: $0.r, col: $0.c) }
        let center = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(max(1, points.count)),
            y: points.map(\.y).reduce(0, +) / CGFloat(max(1, points.count)))
        let text = tacticalReasonTitle(analysis.reason,
                                       includesSugarRush: sugarRushCharged)
        let badge = SKShapeNode(
            rectOf: CGSize(width: min(size.width - 36, max(126, CGFloat(text.count) * 7.2)),
                           height: 28),
            cornerRadius: 14)
        badge.fillColor = UIColor(hex: "#0F172A").withAlphaComponent(0.90)
        badge.strokeColor = sugarRushCharged
            ? UIColor(hex: "#EC4899")
            : UIColor.white.withAlphaComponent(0.35)
        badge.lineWidth = 1.2
        badge.position = CGPoint(x: center.x, y: center.y + tileSize * 0.72)
        badge.zPosition = 750
        badge.alpha = 0
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 10
        label.fontColor = sugarRushCharged
            ? UIColor(hex: "#F9A8D4")
            : UIColor(hex: "#FDE68A")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
        worldNode.addChild(badge)
        badge.run(.fadeIn(withDuration: 0.10))
        ghostNodes.append(badge)
    }

    func tacticalReasonTitle(_ reason: TacticalMoveReason,
                             includesSugarRush: Bool) -> String {
        let base: String
        switch reason {
        case .specialCombo:
            base = String(localized: "POWER COMBO")
        case .objective(let count):
            base = String(localized: "OBJECTIVE +\(count)")
        case .hazard(let count):
            base = count == 1
                ? String(localized: "DEFUSES HAZARD")
                : String(localized: "HAZARDS +\(count)")
        case .createsSpecial(let special):
            let name: String
            switch special {
            case .stripedRow, .stripedCol: name = String(localized: "STRIPE")
            case .wrapped: name = String(localized: "WRAPPED")
            case .colorBomb: name = String(localized: "COLOR BOMB")
            case .bomb: name = String(localized: "BOMB")
            case .fish: name = String(localized: "FISH")
            case .lineBlast: name = String(localized: "LINE BLAST")
            case .rocket: name = String(localized: "ROCKET")
            case .ufo: name = String(localized: "UFO")
            }
            base = String(localized: "CREATES") + " " + name
        case .powerClear(let count):
            base = String(localized: "CLEARS \(count)")
        case .match:
            base = String(localized: "MATCH")
        }
        return includesSugarRush
            ? String(localized: "RUSH CROSS") + " • " + base
            : base
    }

    func clearGhostPreview() {
        for node in ghostNodes {
            node.removeAllActions()
            node.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
        }
        ghostNodes.removeAll()
        ghostTarget = nil
    }

    func isAdjacent(_ a: Pos, _ b: Pos) -> Bool {
        (a.r == b.r && abs(a.c - b.c) == 1) || (a.c == b.c && abs(a.r - b.r) == 1)
    }

    func select(_ p: Pos) {
        firstSelection = p
        firstSelectionNode = nodes[p.r][p.c]
        showSpecialBlastPreview(at: p)
        if let body = firstSelectionNode?.childNode(withName: "body") as? SKShapeNode {
            body.strokeColor = skin.tileHighlight
            body.lineWidth = 3
            body.run(SKAction.repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.18),
                .scale(to: 1.0, duration: 0.18)
            ])), withKey: "pulse")
        }
    }

    func deselect() {
        if let node = firstSelectionNode, let body = node.childNode(withName: "body") as? SKShapeNode {
            body.removeAction(forKey: "pulse")
            body.setScale(1.0)
            body.strokeColor = skin.tileBorder
            body.lineWidth = 1
        }
        clearSpecialBlastPreview()
        firstSelection = nil
        firstSelectionNode = nil
    }

    /// When a tile holding a special is selected, highlight the tiles its special
    /// would clear — teaches what each special does and rewards planning.
    func showSpecialBlastPreview(at p: Pos) {
        clearSpecialBlastPreview()
        guard grid[p.r][p.c]?.special != nil else { return }
        var area = Engine.expandMatchesWithSpecials(grid, [p], bigger: specialBlastIsExpanded)
        area = addingObjectiveFishTargets(to: area)
        for q in area where !(q.r == p.r && q.c == p.c) {
            guard nodes[q.r][q.c] != nil else { continue }
            let hl = SKShapeNode(rectOf: CGSize(width: tileSize * 0.9, height: tileSize * 0.9),
                                 cornerRadius: tileSize * 0.2)
            hl.fillColor = UIColor(hex: "#FACC15").withAlphaComponent(0.20)
            hl.strokeColor = UIColor(hex: "#FBBF24").withAlphaComponent(0.7)
            hl.lineWidth = 2
            hl.position = point(forRow: q.r, col: q.c)
            hl.zPosition = 60
            hl.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.4),
                                             .fadeAlpha(to: 1.0, duration: 0.4)])))
            worldNode.addChild(hl)
            specialPreviewNodes.append(hl)
        }
    }

    func clearSpecialBlastPreview() {
        for n in specialPreviewNodes { n.removeFromParent() }
        specialPreviewNodes.removeAll()
    }
}
