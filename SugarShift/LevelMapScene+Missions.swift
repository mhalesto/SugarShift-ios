import SpriteKit

// Daily missions strip + card
extension LevelMapScene {

    /// Fixed pill above the daily streak strip: shows today's mission count
    /// and flags unclaimed rewards. Tapping opens the missions card.
    func buildMissionsStrip() {
        missionsStripNode?.removeFromParent()
        missionsStripNode = nil

        let missions = DailyMissions.missions()
        let done = missions.filter { DailyMissions.isComplete($0) }
        let claimable = done.contains { !Persistence.hasClaimedMission(id: $0.id) }

        let strip = SKNode()
        strip.zPosition = 997
        strip.name = "missionsStrip"
        strip.position = CGPoint(x: 0, y: missionsStripCenterY)
        addChild(strip)
        missionsStripNode = strip

        let width = min(size.width - 34, 346)
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 40), cornerRadius: 20)
        bg.fillColor = (claimable ? UIColor(hex: "#FEF9C3") : UIColor.white).withAlphaComponent(0.92)
        bg.strokeColor = claimable ? UIColor(hex: "#FACC15") : UIColor(hex: "#FBCFE8")
        bg.lineWidth = claimable ? 1.6 : 1
        bg.name = "missionsStrip"
        strip.addChild(bg)

        let icon = Icons.sprite(Icons.Name.star,
                                size: 15,
                                weight: .heavy,
                                tint: UIColor(hex: claimable ? "#B45309" : "#EC4899"))
        icon.position = CGPoint(x: -width / 2 + 22, y: 0)
        strip.addChild(icon)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        let status = claimable
            ? String(localized: "Reward ready — tap to claim!")
            : String(localized: "\(done.count) of \(missions.count) done")
        label.text = String(localized: "Missions") + "  •  " + status
        label.fontSize = 11.5
        label.fontColor = UIColor(hex: "#0F172A")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 11, y: 0)
        label.name = "missionsStrip"
        fitLabel(label, maxWidth: width - 56, minFontSize: 8)
        strip.addChild(label)

        strip.isAccessibilityElement = true
        strip.accessibilityLabel = String(localized: "Daily missions. \(done.count) of \(missions.count) complete.")
    }

    func showMissionsCard() {
        missionsCard?.removeFromParent()
        let overlay = makeOverlay(name: "missionsCard")
        let cardW = min(size.width - 34, 344)
        let cardH: CGFloat = 396
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.75)
        card.lineWidth = 1
        card.zPosition = 1
        overlay.addChild(card)

        addCardTitle(String(localized: "Daily Missions"),
                     subtitle: String(localized: "Fresh goals every day — finish them for coins"),
                     to: card, y: cardH / 2 - 36)

        let missions = DailyMissions.missions()
        var y = cardH / 2 - 116
        for mission in missions {
            addMissionRow(mission, to: card, width: cardW - 44, y: y)
            y -= 88
        }

        addCloseButton(to: card, width: cardW, y: -cardH / 2 + 30, name: "missionsCardClose")
        addChild(overlay)
        missionsCard = overlay
        Analytics.track("missions_opened",
                        properties: ["completed": "\(missions.filter { DailyMissions.isComplete($0) }.count)"])
    }

    private func addMissionRow(_ mission: DailyMission,
                               to card: SKNode,
                               width: CGFloat,
                               y: CGFloat) {
        let progress = min(Persistence.missionProgress(id: mission.id), mission.target)
        let complete = progress >= mission.target
        let claimed = Persistence.hasClaimedMission(id: mission.id)

        let row = SKNode()
        row.position = CGPoint(x: 0, y: y)
        card.addChild(row)

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 76), cornerRadius: 16)
        bg.fillColor = UIColor(hex: claimed ? "#F0FDF4" : "#F8FAFC")
        bg.strokeColor = UIColor(hex: claimed ? "#BBF7D0" : "#E2E8F0")
        bg.lineWidth = 1
        row.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = mission.title
        title.fontSize = 13
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -width / 2 + 14, y: 20)
        fitLabel(title, maxWidth: width - 100, minFontSize: 10)
        row.addChild(title)

        // Progress bar with count overlaid at its right end
        let barW = width - 118
        let track = SKShapeNode(rectOf: CGSize(width: barW, height: 10), cornerRadius: 5)
        track.fillColor = UIColor(hex: "#E2E8F0")
        track.strokeColor = .clear
        track.position = CGPoint(x: -width / 2 + 14 + barW / 2, y: -6)
        row.addChild(track)

        let frac = mission.target > 0 ? CGFloat(progress) / CGFloat(mission.target) : 0
        if frac > 0 {
            let fillW = max(10, barW * min(1, frac))
            let fill = SKShapeNode(rectOf: CGSize(width: fillW, height: 10), cornerRadius: 5)
            fill.fillColor = UIColor(hex: complete ? "#34D399" : "#F472B6")
            fill.strokeColor = .clear
            fill.position = CGPoint(x: -width / 2 + 14 + fillW / 2, y: -6)
            row.addChild(fill)
        }

        let count = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        count.text = "\(progress)/\(mission.target)"
        count.fontSize = 10
        count.fontColor = UIColor(hex: "#64748B")
        count.verticalAlignmentMode = .center
        count.horizontalAlignmentMode = .left
        count.position = CGPoint(x: -width / 2 + 14, y: -24)
        row.addChild(count)

        // Right side: claim pill (complete), reward preview (in progress),
        // or a checkmark (claimed).
        let pillName = complete && !claimed ? "missionClaim_\(mission.id)" : nil
        let pill = SKShapeNode(rectOf: CGSize(width: 74, height: 34), cornerRadius: 17)
        pill.position = CGPoint(x: width / 2 - 51, y: -2)
        pill.name = pillName
        if claimed {
            pill.fillColor = UIColor(hex: "#DCFCE7")
            pill.strokeColor = UIColor(hex: "#86EFAC")
        } else if complete {
            pill.fillColor = UIColor(hex: "#FACC15")
            pill.strokeColor = UIColor(hex: "#B45309")
        } else {
            pill.fillColor = UIColor(hex: "#F1F5F9")
            pill.strokeColor = UIColor(hex: "#CBD5E1")
        }
        pill.lineWidth = 1.2
        row.addChild(pill)

        let pillLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        if claimed {
            pillLabel.text = "✓"
            pillLabel.fontColor = UIColor(hex: "#15803D")
        } else if complete {
            pillLabel.text = String(localized: "CLAIM")
            pillLabel.fontColor = UIColor(hex: "#422006")
        } else {
            pillLabel.text = "+\(mission.rewardCoins)"
            pillLabel.fontColor = UIColor(hex: "#64748B")
        }
        pillLabel.fontSize = 12
        pillLabel.verticalAlignmentMode = .center
        pillLabel.horizontalAlignmentMode = .center
        pillLabel.name = pillName
        pill.addChild(pillLabel)

        row.isAccessibilityElement = true
        let state = claimed
            ? String(localized: "Reward claimed.")
            : complete
                ? String(localized: "Complete. Double tap to claim \(mission.rewardCoins) coins.")
                : String(localized: "\(progress) of \(mission.target) done.")
        row.accessibilityLabel = "\(mission.title). \(state)"
    }

    func handleMissionsTap(at p: CGPoint) {
        var node: SKNode? = atPoint(p)
        while let cur = node {
            if let name = cur.name {
                if name == "missionsCardClose" {
                    missionsCard?.removeFromParent()
                    missionsCard = nil
                    return
                }
                if name.hasPrefix("missionClaim_") {
                    let id = String(name.dropFirst("missionClaim_".count))
                    if let mission = DailyMissions.missions().first(where: { $0.id == id }),
                       DailyMissions.claim(mission) != nil {
                        Effects.notify(.success)
                        refreshHUD()
                        buildMissionsStrip()
                        showMissionsCard()
                    }
                    return
                }
            }
            node = cur.parent
        }
    }
}
