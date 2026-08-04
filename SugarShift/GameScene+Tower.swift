import SpriteKit

// Sugar Tower — floor interstitials (perk draft on a win, run-over on a
// loss) and the relaunch path between floors.
extension GameScene {

    /// Locks the player into the floor the moment they spend a move on it.
    /// From here, leaving without resolving the floor ends the run — otherwise
    /// force-quitting a doomed floor would dodge the mode's one-loss rule.
    func commitTowerFloorIfNeeded() {
        guard !levelEnded, var run = towerRun, !run.floorInProgress else { return }
        run.floorInProgress = true
        towerRun = run
        TowerMode.markFloorInProgress()
    }

    func endTowerFloor(won: Bool) {
        guard var run = towerRun else { return }
        // The floor resolved, so it is no longer abandonable either way.
        run.floorInProgress = false
        Analytics.track(won ? "tower_floor_win" : "tower_floor_fail",
                        properties: ["week": run.weekKey,
                                     "floor": "\(run.floor)",
                                     "score": "\(score)",
                                     "perks": run.perks.map(\.rawValue).joined(separator: ",")])
        if won {
            Effects.notify(.success)
            Audio.shared.play(.win)
            let coins = TowerMode.coinReward(floor: run.floor, perks: run.perks)
            Persistence.cash += coins
            run.coinsEarned += coins
            Persistence.towerBestFloor = max(Persistence.towerBestFloor, run.floor)
            let clearedFloor = run.floor
            run.floor += 1
            TowerMode.save(run)
            towerRun = run
            spawnConfetti()
            showTowerDraftCard(clearedFloor: clearedFloor, coins: coins, run: run)
        } else {
            Effects.notify(.error)
            Audio.shared.play(.lose)
            TowerMode.endRun(run)
            towerRun = nil
            showTowerRunOverCard(endedRun: run)
        }
    }

    // MARK: - Cards

    private func makeTowerOverlay() -> (overlay: SKNode, card: SKShapeNode, cardSize: CGSize) {
        towerOverlay?.removeFromParent()
        let overlay = SKNode()
        overlay.zPosition = 1500

        let scrim = SKShapeNode(rectOf: size)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        overlay.addChild(scrim)

        let cardSize = CGSize(width: min(size.width - 36, 340), height: 466)
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 24)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor(hex: "#A855F7").withAlphaComponent(0.6)
        card.lineWidth = 2
        card.zPosition = 1
        overlay.addChild(card)

        addChild(overlay)
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.18))
        towerOverlay = overlay
        return (overlay, card, cardSize)
    }

    private func towerLabel(_ text: String, size: CGFloat, color: UIColor,
                            weight: String = "AvenirNext-Heavy") -> SKLabelNode {
        let label = SKLabelNode(fontNamed: weight)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    /// Win interstitial: floor reward summary + a draft of one of three
    /// perks. Tapping a perk drafts it and immediately climbs; "Take a break"
    /// keeps the run saved and returns to the map.
    func showTowerDraftCard(clearedFloor: Int, coins: Int, run: TowerRun) {
        let (_, card, cardSize) = makeTowerOverlay()
        let top = cardSize.height / 2

        let title = towerLabel(String(localized: "FLOOR \(clearedFloor) CLEARED!"),
                               size: 22, color: UIColor(hex: "#7C3AED"))
        title.position = CGPoint(x: 0, y: top - 38)
        card.addChild(title)

        let coinsLabel = towerLabel(String(localized: "+\(coins) coins  •  Next: Floor \(run.floor)"),
                                    size: 13, color: UIColor(hex: "#64748B"),
                                    weight: "AvenirNext-DemiBold")
        coinsLabel.position = CGPoint(x: 0, y: top - 64)
        card.addChild(coinsLabel)

        // Naming the next floor's objective is what turns the draft into a
        // decision — Bigger Blasts reads very differently before "clear the
        // blockers" than before "reach a score".
        let nextGoal = TowerMode.floorConfig(weekKey: run.weekKey,
                                             floor: run.floor,
                                             perks: run.perks).goal
        let goalLabel = towerLabel(String(localized: "Floor \(run.floor) objective: \(nextGoal.title)"),
                                   size: 12, color: UIColor(hex: "#7C3AED"),
                                   weight: "AvenirNext-DemiBold")
        goalLabel.position = CGPoint(x: 0, y: top - 86)
        card.addChild(goalLabel)

        let prompt = towerLabel(String(localized: "Draft a perk for the climb:"),
                                size: 14, color: UIColor(hex: "#0F172A"))
        prompt.position = CGPoint(x: 0, y: top - 112)
        card.addChild(prompt)

        let choices = TowerMode.perkChoices(weekKey: run.weekKey,
                                            floor: clearedFloor,
                                            owned: run.perks)
        var y = top - 166
        for perk in choices {
            let row = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 62),
                                  cornerRadius: 16)
            row.fillColor = UIColor(hex: "#FAF5FF")
            row.strokeColor = UIColor(hex: "#D8B4FE")
            row.lineWidth = 1.4
            row.position = CGPoint(x: 0, y: y)
            row.name = "towerPerk_\(perk.rawValue)"
            card.addChild(row)

            let emoji = SKLabelNode(text: perk.emoji)
            emoji.fontSize = 26
            emoji.verticalAlignmentMode = .center
            emoji.position = CGPoint(x: -cardSize.width / 2 + 44, y: 0)
            row.addChild(emoji)

            // Owned stacks are shown because the cap is what makes the draft a
            // choice — a player needs to see when a card is one away from full.
            // The title is already localized and the badge is bare numerals,
            // so this composition needs no catalog entry of its own.
            let owned = run.perks.filter { $0 == perk }.count
            let stackText = owned > 0
                ? "\(perk.title)  ×\(owned)/\(TowerPerk.maxStacks)"
                : perk.title
            let name = towerLabel(stackText, size: 14, color: UIColor(hex: "#0F172A"))
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -cardSize.width / 2 + 70, y: 11)
            row.addChild(name)

            let detail = towerLabel(perk.summary, size: 10.5, color: UIColor(hex: "#64748B"),
                                    weight: "AvenirNext-DemiBold")
            detail.horizontalAlignmentMode = .left
            detail.position = CGPoint(x: -cardSize.width / 2 + 70, y: -12)
            row.addChild(detail)

            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(stackText). \(perk.summary)"
            row.accessibilityTraits = .button

            y -= 74
        }

        let leave = SKShapeNode(rectOf: CGSize(width: 180, height: 32), cornerRadius: 16)
        leave.fillColor = UIColor(hex: "#F8FAFC")
        leave.strokeColor = UIColor(hex: "#CBD5E1")
        leave.lineWidth = 1
        leave.position = CGPoint(x: 0, y: -cardSize.height / 2 + 32)
        leave.name = "towerLeave"
        card.addChild(leave)
        let leaveLabel = towerLabel(String(localized: "Take a break (run saved)"),
                                    size: 11.5, color: UIColor(hex: "#475569"),
                                    weight: "AvenirNext-DemiBold")
        leaveLabel.name = "towerLeave"
        leave.addChild(leaveLabel)
        leave.isAccessibilityElement = true
        leave.accessibilityLabel = leaveLabel.text
        leave.accessibilityTraits = .button
    }

    /// Loss interstitial: the run is over — summary + restart or exit.
    func showTowerRunOverCard(endedRun: TowerRun) {
        let (_, card, cardSize) = makeTowerOverlay()
        let top = cardSize.height / 2
        let cleared = endedRun.floor - 1

        let title = towerLabel(String(localized: "RUN OVER"), size: 24,
                               color: UIColor(hex: "#EF4444"))
        title.position = CGPoint(x: 0, y: top - 40)
        card.addChild(title)

        let rows: [(String, String)] = [
            (String(localized: "Floors cleared"), "\(cleared)"),
            (String(localized: "Coins earned"), "\(endedRun.coinsEarned)"),
            (String(localized: "Best ever"), String(localized: "Floor \(Persistence.towerBestFloor)"))
        ]
        var y = top - 96
        for row in rows {
            let key = towerLabel(row.0, size: 13, color: UIColor(hex: "#64748B"),
                                 weight: "AvenirNext-DemiBold")
            key.horizontalAlignmentMode = .left
            key.position = CGPoint(x: -cardSize.width / 2 + 28, y: y)
            card.addChild(key)
            let value = towerLabel(row.1, size: 14, color: UIColor(hex: "#0F172A"))
            value.horizontalAlignmentMode = .right
            value.position = CGPoint(x: cardSize.width / 2 - 28, y: y)
            card.addChild(value)
            y -= 34
        }

        let hint = towerLabel(String(localized: "Same tower all week — climb smarter."),
                              size: 11.5, color: UIColor(hex: "#7C3AED"),
                              weight: "AvenirNext-DemiBold")
        hint.position = CGPoint(x: 0, y: y - 6)
        card.addChild(hint)

        let retry = SKShapeNode(rectOf: CGSize(width: cardSize.width - 60, height: 44),
                                cornerRadius: 22)
        retry.fillColor = UIColor(hex: "#A855F7")
        retry.strokeColor = .clear
        retry.position = CGPoint(x: 0, y: -cardSize.height / 2 + 96)
        retry.name = "towerNewRun"
        card.addChild(retry)
        let retryLabel = towerLabel(String(localized: "New run"), size: 15, color: .white)
        retryLabel.name = "towerNewRun"
        retry.addChild(retryLabel)
        retry.isAccessibilityElement = true
        retry.accessibilityLabel = retryLabel.text
        retry.accessibilityTraits = .button

        let exit = SKShapeNode(rectOf: CGSize(width: cardSize.width - 60, height: 36),
                               cornerRadius: 18)
        exit.fillColor = UIColor(hex: "#F8FAFC")
        exit.strokeColor = UIColor(hex: "#CBD5E1")
        exit.lineWidth = 1
        exit.position = CGPoint(x: 0, y: -cardSize.height / 2 + 44)
        exit.name = "towerExit"
        card.addChild(exit)
        let exitLabel = towerLabel(String(localized: "Back to map"), size: 13,
                                   color: UIColor(hex: "#475569"),
                                   weight: "AvenirNext-DemiBold")
        exitLabel.name = "towerExit"
        exit.addChild(exitLabel)
        exit.isAccessibilityElement = true
        exit.accessibilityLabel = exitLabel.text
        exit.accessibilityTraits = .button
    }

    // MARK: - Taps + flow

    func handleTowerOverlayTap(at point: CGPoint) {
        guard let overlay = towerOverlay else { return }
        let local = overlay.convert(point, from: self)
        var hit: SKNode? = overlay.atPoint(local)
        while let node = hit {
            if let name = node.name {
                if name.hasPrefix("towerPerk_") {
                    let raw = String(name.dropFirst("towerPerk_".count))
                    if let perk = TowerPerk(rawValue: raw), var run = towerRun {
                        run.perks.append(perk)
                        TowerMode.save(run)
                        towerRun = run
                        Analytics.track("tower_perk_drafted",
                                        properties: ["perk": perk.rawValue,
                                                     "floor": "\(run.floor)"])
                        Effects.haptic(.medium)
                        launchTowerFloor()
                    }
                    return
                }
                switch name {
                case "towerLeave", "towerExit":
                    dismissTowerOverlay()
                    exitTowerToMap()
                    return
                case "towerNewRun":
                    TowerMode.startNewRun()
                    towerRun = TowerMode.activeRun()
                    launchTowerFloor()
                    return
                default:
                    break
                }
            }
            hit = node.parent
        }
    }

    /// Relaunches the scene on the active run's current floor. Mirrors
    /// `advanceToLevel` but never touches campaign progression.
    func launchTowerFloor() {
        dismissTowerOverlay()
        endLevelCard?.dismiss()
        endLevelCard = nil
        levelEnded = false
        isResolving = false
        cascadeDepth = 0
        pendingLifeLoss = false
        continueUsedThisAttempt = false
        pendingDoubleRewards = []
        deselect()
        levelConfig = Levels.config(for: Levels.towerLevel)
        initialDailyChallenge = nil
        dailyChallengeRun = nil
        isDailyChallengeRun = false
        rebuildChapterBackdrop()
        rebuildHUD()
        layoutBoard()
        startNewGame()
    }

    private func dismissTowerOverlay() {
        towerOverlay?.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        towerOverlay = nil
    }

    private func exitTowerToMap() {
        if let onChoose = onChooseLevel {
            onChoose()
        } else {
            // No host wired up — restart the floor locally so the button is
            // never a dead-end (same fallback as the campaign card).
            launchTowerFloor()
        }
    }
}
