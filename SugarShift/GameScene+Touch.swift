import SpriteKit

// Touch handling + pre-swap ghost preview
extension GameScene {
    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // Any interaction clears a lingering idle hint so arrows never stack up.
        cancelIdleHint()

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
            if n.name == "movesQuantityBadge" {
                showQuantityPopup()
                Effects.haptic(.light)
                return
            }
            if n.name == "settingsButton" {
                openSettings()
                return
            }
            if n.name == "cartButton" {
                openShop()
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
            if let name = n.name, name.hasPrefix("booster:") {
                let label = String(name.dropFirst("booster:".count))
                handleBoosterTap(label)
                return
            }
            node = n.parent
        }

        // 3. Booster mode active — next tile tap consumes it
        if boosterMode != .none, let pos = cellAt(p), grid[pos.r][pos.c] != nil {
            executeBoosterOnTile(pos)
            return
        }

        // 3. Tile interaction
        guard !isResolving else { return }
        guard let pos = cellAt(p), grid[pos.r][pos.c] != nil else { return }
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

        guard !isResolving, let t = touches.first, let start = dragStartPoint, let first = firstSelection else { return }
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

    /// Renders a faded outline on every tile that *would clear* if the player
    /// released the drag right now. Activating an existing special is treated
    /// as a successful preview too. No-op when the swap wouldn't match.
    func showGhostPreview(from a: Pos, to b: Pos) {
        guard grid[b.r][b.c] != nil else { return }
        let swapResult = Engine.swapIfValid(grid, a, b)
        guard swapResult.didSwap else { return }

        var clears: Set<Pos>
        if isSpecialActivationSwap(a, b) {
            // Highlight the activation pair + the area the special would clear.
            clears = previewClearsForSpecialSwap(a, b)
        } else {
            clears = Engine.findMatches(swapResult.grid)
            clears = Engine.expandMatchesWithSpecials(swapResult.grid,
                                                      clears,
                                                      bigger: specialBlastIsExpanded)
        }
        guard !clears.isEmpty else { return }

        for p in clears {
            let pt = point(forRow: p.r, col: p.c)
            let outline = SKShapeNode(rectOf: CGSize(width: tileSize * 0.92,
                                                     height: tileSize * 0.92),
                                       cornerRadius: tileSize * 0.22)
            outline.fillColor = UIColor.white.withAlphaComponent(0.18)
            outline.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.92)
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
    }

    func clearGhostPreview() {
        for node in ghostNodes {
            node.removeAllActions()
            node.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
        }
        ghostNodes.removeAll()
        ghostTarget = nil
    }

    func isSpecialActivationSwap(_ a: Pos, _ b: Pos) -> Bool {
        let sa = grid[a.r][a.c]?.special
        let sb = grid[b.r][b.c]?.special
        if sa == .colorBomb || sb == .colorBomb { return true }
        if sa != nil && sb != nil { return true }
        return false
    }

    /// Conservative preview of what a special-activation swap will clear so
    /// the ghost outlines roughly match the actual blast. Falls back to a
    /// 3×3 around the swap if we can't infer a better region.
    func previewClearsForSpecialSwap(_ a: Pos, _ b: Pos) -> Set<Pos> {
        var clears: Set<Pos> = [a, b]
        let sa = grid[a.r][a.c]?.special
        let sb = grid[b.r][b.c]?.special
        let colorA = grid[a.r][a.c]?.color
        let colorB = grid[b.r][b.c]?.color

        if sa == .colorBomb, let color = colorB {
            for r in 0..<rows {
                for c in 0..<cols where grid[r][c]?.color == color {
                    clears.insert(Pos(r: r, c: c))
                }
            }
        }
        if sb == .colorBomb, let color = colorA {
            for r in 0..<rows {
                for c in 0..<cols where grid[r][c]?.color == color {
                    clears.insert(Pos(r: r, c: c))
                }
            }
        }
        if sa == .stripedRow || sb == .stripedRow {
            for c in 0..<cols { clears.insert(Pos(r: a.r, c: c)) }
        }
        if sa == .stripedCol || sb == .stripedCol {
            for r in 0..<rows { clears.insert(Pos(r: r, c: a.c)) }
        }
        if sa == .wrapped || sb == .wrapped || sa == .bomb || sb == .bomb {
            for dr in -1...1 {
                for dc in -1...1 {
                    let p = Pos(r: a.r + dr, c: a.c + dc)
                    if p.r >= 0, p.r < rows, p.c >= 0, p.c < cols, grid[p.r][p.c] != nil {
                        clears.insert(p)
                    }
                }
            }
        }
        return clears
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
        let area = Engine.expandMatchesWithSpecials(grid, [p], bigger: specialBlastIsExpanded)
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
