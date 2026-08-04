import SpriteKit

// Sugar Tower — bottom-bar icon, entry card, and tap handling.
extension LevelMapScene {

    func makeTowerTabIcon() -> SKNode {
        let node = SKNode()
        let shadow = SKShapeNode(circleOfRadius: 14)
        shadow.fillColor = UIColor(white: 0, alpha: 0.16)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        node.addChild(shadow)

        let disc = SKShapeNode(circleOfRadius: 14)
        disc.fillColor = UIColor(hex: "#A855F7")
        disc.strokeColor = .white
        disc.lineWidth = 1.5
        node.addChild(disc)

        // Crenellated tower silhouette
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -5, y: -8))
        path.addLine(to: CGPoint(x: 5, y: -8))
        path.addLine(to: CGPoint(x: 5, y: 6))
        path.addLine(to: CGPoint(x: 2.8, y: 6))
        path.addLine(to: CGPoint(x: 2.8, y: 2.5))
        path.addLine(to: CGPoint(x: 1, y: 2.5))
        path.addLine(to: CGPoint(x: 1, y: 6))
        path.addLine(to: CGPoint(x: -1, y: 6))
        path.addLine(to: CGPoint(x: -1, y: 2.5))
        path.addLine(to: CGPoint(x: -2.8, y: 2.5))
        path.addLine(to: CGPoint(x: -2.8, y: 6))
        path.addLine(to: CGPoint(x: -5, y: 6))
        path.close()
        let tower = SKShapeNode(path: path.cgPath)
        tower.fillColor = UIColor(hex: "#FDF4FF")
        tower.strokeColor = UIColor(hex: "#6D28D9")
        tower.lineWidth = 1
        node.addChild(tower)

        let window = SKShapeNode(circleOfRadius: 1.6)
        window.fillColor = UIColor(hex: "#6D28D9")
        window.strokeColor = .clear
        window.position = CGPoint(x: 0, y: -2)
        node.addChild(window)
        return node
    }

    func showTowerCard() {
        towerCard?.removeFromParent()
        let overlay = makeOverlay(name: "towerCard")
        let cardW = min(size.width - 34, 344)
        let cardH: CGFloat = 400
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor(hex: "#A855F7").withAlphaComponent(0.6)
        card.lineWidth = 2
        card.zPosition = 1
        overlay.addChild(card)

        addCardTitle(String(localized: "Sugar Tower"),
                     subtitle: String(localized: "Climb. Draft perks. One loss ends the run."),
                     to: card, y: cardH / 2 - 36)

        let run = TowerMode.activeRun()
        let best = Persistence.towerBestFloor
        let week = TowerMode.weekKey()

        var rows: [(String, String)] = [
            (String(localized: "This week's tower"), week),
            (String(localized: "Best floor"), best > 0 ? "\(best)" : "—")
        ]
        if let run {
            rows.append((String(localized: "Run in progress"),
                         String(localized: "Floor \(run.floor)")))
            let perksText = run.perks.isEmpty
                ? String(localized: "No perks yet")
                : run.perks.map(\.emoji).joined(separator: " ")
            rows.append((String(localized: "Perks"), perksText))
            rows.append((String(localized: "Run coins"), "\(run.coinsEarned)"))
        }
        var y = cardH / 2 - 112
        for row in rows {
            addPreviewRow(to: card, width: cardW - 48, title: row.0, value: row.1, y: y)
            y -= 38
        }

        let rules = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        rules.text = String(localized: "Same tower for everyone all week. No boosters, no continues.")
        rules.fontSize = 10.5
        rules.fontColor = UIColor(hex: "#7C3AED")
        rules.verticalAlignmentMode = .center
        rules.horizontalAlignmentMode = .center
        rules.position = CGPoint(x: 0, y: -cardH / 2 + 128)
        fitLabel(rules, maxWidth: cardW - 44, minFontSize: 8)
        card.addChild(rules)

        let climb = SKShapeNode(rectOf: CGSize(width: cardW - 60, height: 46), cornerRadius: 23)
        climb.fillColor = UIColor(hex: "#A855F7")
        climb.strokeColor = .clear
        climb.position = CGPoint(x: 0, y: -cardH / 2 + 88)
        climb.name = "towerClimb"
        card.addChild(climb)
        let climbLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        climbLabel.text = run != nil
            ? String(localized: "Continue — Floor \(run?.floor ?? 1)")
            : String(localized: "Start the climb")
        climbLabel.fontSize = 15
        climbLabel.fontColor = .white
        climbLabel.verticalAlignmentMode = .center
        climbLabel.horizontalAlignmentMode = .center
        climbLabel.name = "towerClimb"
        climb.addChild(climbLabel)
        climb.isAccessibilityElement = true
        climb.accessibilityLabel = climbLabel.text
        climb.accessibilityTraits = .button

        #if DEBUG
        let designer = makeSmallDebugButton(text: "🛠", name: "towerDesigner")
        designer.position = CGPoint(x: cardW / 2 - 40, y: cardH / 2 - 32)
        card.addChild(designer)
        #endif

        addCloseButton(to: card, width: cardW, y: -cardH / 2 + 30, name: "towerCardClose")
        addChild(overlay)
        towerCard = overlay
        Analytics.track("tower_card_opened",
                        properties: ["active_run": "\(run != nil)",
                                     "best": "\(best)"])
    }

    func handleTowerCardTap(at p: CGPoint) {
        var node: SKNode? = atPoint(p)
        while let cur = node {
            switch cur.name {
            case "towerClimb":
                towerCard?.removeFromParent()
                towerCard = nil
                if TowerMode.activeRun() == nil { TowerMode.startNewRun() }
                onLevelSelected?(Levels.towerLevel, nil)
                return
            case "towerCardClose":
                towerCard?.removeFromParent()
                towerCard = nil
                return
            #if DEBUG
            case "towerDesigner":
                towerCard?.removeFromParent()
                towerCard = nil
                showDebugDesignerMenu()
                return
            #endif
            default:
                node = cur.parent
            }
        }
    }
}
