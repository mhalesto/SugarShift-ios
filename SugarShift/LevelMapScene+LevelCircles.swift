import SpriteKit

// Level circles + avatar marker
extension LevelMapScene {
    // MARK: - Level circles

    func buildChapterBanners() {
        let starts = WorldThemes.all.map { $0.levels.lowerBound }
        for start in starts {
            guard let p = levelPositions[start] else { continue }
            let chapter = Levels.chapter(for: start)
            let theme = WorldThemes.theme(for: start)
            let bannerW = min(size.width - 52, 330)
            let banner = SKNode()
            banner.position = CGPoint(x: 0, y: p.y + (start == 1 ? 92 : -82))
            banner.zPosition = 7

            let bg = SKShapeNode(rectOf: CGSize(width: bannerW, height: 52), cornerRadius: 14)
            bg.fillColor = UIColor(hex: theme.cardPalette.top).withAlphaComponent(0.96)
            bg.strokeColor = theme.boardRimColor
            bg.lineWidth = 1.5
            banner.addChild(bg)

            let crown = GameArt.boardSprite(theme.comboHeroAsset ?? "special_color_bomb", fitting: CGSize(width: 31, height: 35))
            crown.position = CGPoint(x: -bannerW / 2 + 24, y: 8)
            banner.addChild(crown)

            let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            title.text = chapter.title
            title.fontSize = Persistence.largeText ? 16 : 15
            title.fontColor = UIColor(hex: theme.cardPalette.ink)
            title.verticalAlignmentMode = .center
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: -bannerW / 2 + 46, y: 9)
            banner.addChild(title)

            let range = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            range.text = "Levels \(chapter.range.lowerBound)-\(chapter.range.upperBound)"
            range.fontSize = 11
            range.fontColor = UIColor(hex: theme.cardPalette.ink).withAlphaComponent(0.8)
            range.verticalAlignmentMode = .center
            range.horizontalAlignmentMode = .left
            range.position = CGPoint(x: -bannerW / 2 + 46, y: -11)
            banner.addChild(range)

            world.addChild(banner)
        }
    }

    func buildRewardChestsAndGates() {
        let gateLevels = [25, 50, 75, 100, 150, 200]
        for gate in gateLevels {
            guard let p = levelPositions[gate] else { continue }
            let node = SKNode()
            node.position = CGPoint(x: 0, y: p.y + 78)
            node.zPosition = 9
            node.name = "lvl:\(gate)"

            let arch = SKShapeNode(rectOf: CGSize(width: 144, height: 46), cornerRadius: 14)
            arch.fillColor = gate >= 100 ? UIColor(hex: "#0F172A").withAlphaComponent(0.92) : UIColor.white.withAlphaComponent(0.90)
            arch.strokeColor = gate >= 100 ? UIColor(hex: "#FACC15") : UIColor(hex: "#F472B6")
            arch.lineWidth = 2
            node.addChild(arch)

            let crown = Icons.sprite(gate >= 100 ? Icons.Name.crown : "flag.checkered",
                                     size: 17,
                                     weight: .heavy,
                                     tint: gate >= 100 ? UIColor(hex: "#FACC15") : UIColor(hex: "#EC4899"))
            crown.position = CGPoint(x: -50, y: 0)
            node.addChild(crown)

            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = gate == 200 ? String(localized: "Final Gate") : String(localized: "Gate \(gate)")
            label.fontSize = 13
            label.fontColor = gate >= 100 ? .white : UIColor(hex: "#0F172A")
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -28, y: 0)
            node.addChild(label)
            world.addChild(node)
        }

        for level in stride(from: 10, through: levelCount, by: 10) {
            guard let p = levelPositions[level] else { continue }
            let chest = makeRewardChest(claimed: Persistence.hasClaimedMilestoneReward(for: level))
            chest.position = CGPoint(x: p.x + 48, y: p.y - 4)
            chest.zPosition = 10
            chest.name = "lvl:\(level)"
            world.addChild(chest)
        }
    }

    func makeRewardChest(claimed: Bool) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: 34, height: 26), cornerRadius: 6)
        body.fillColor = claimed ? UIColor(hex: "#CBD5E1") : UIColor(hex: "#F59E0B")
        body.strokeColor = UIColor(hex: "#92400E")
        body.lineWidth = 1.5
        node.addChild(body)

        let lid = SKShapeNode(rectOf: CGSize(width: 38, height: 12), cornerRadius: 6)
        lid.fillColor = claimed ? UIColor(hex: "#94A3B8") : UIColor(hex: "#FBBF24")
        lid.strokeColor = UIColor(hex: "#92400E")
        lid.lineWidth = 1.4
        lid.position = CGPoint(x: 0, y: 10)
        node.addChild(lid)

        let lock = Icons.sprite(claimed ? "checkmark.seal.fill" : "sparkles",
                                size: 13,
                                weight: .heavy,
                                tint: .white)
        lock.position = CGPoint(x: 0, y: -1)
        node.addChild(lock)
        if !claimed {
            node.run(.repeatForever(.sequence([
                .scale(to: 1.10, duration: 0.75),
                .scale(to: 1.0, duration: 0.75)
            ])))
        }
        return node
    }

    func buildEventPins() {
        for event in Levels.activeEvents() {
            guard let p = levelPositions[event.level] else { continue }
            let pin = SKNode()
            pin.position = CGPoint(x: p.x - 48, y: p.y + 4)
            pin.zPosition = 11
            pin.name = "lvl:\(event.level)"

            let bg = SKShapeNode(circleOfRadius: 18)
            bg.fillColor = UIColor(hex: "#22D3EE")
            bg.strokeColor = .white
            bg.lineWidth = 2
            bg.glowWidth = 4
            pin.addChild(bg)

            let icon = Icons.sprite(event.title.contains("Crown") ? Icons.Name.crown : Icons.Name.star,
                                    size: 15,
                                    weight: .heavy,
                                    tint: .white)
            pin.addChild(icon)
            world.addChild(pin)
        }
    }

    func buildLevelNodes() {
        let unlocked = Persistence.highestUnlockedLevel
        for n in 1...levelCount {
            guard let p = levelPositions[n] else { continue }
            let isUnlocked = n <= unlocked
            let stars = Persistence.starsForLevel(n)
            let isCurrent = (n == Persistence.currentLevel)

            let node = makeLevelNode(number: n,
                                     unlocked: isUnlocked,
                                     stars: stars,
                                     isCurrent: isCurrent)
            node.position = p
            node.zPosition = 8
            node.name = "lvl:\(n)"
            world.addChild(node)
            levelNodes[n] = node
        }
    }

    func makeLevelNode(number n: Int,
                               unlocked: Bool,
                               stars: Int,
                               isCurrent: Bool) -> SKNode {
        let container = SKNode()

        container.isAccessibilityElement = true
        if unlocked {
            container.accessibilityLabel = stars > 0
                ? String(localized: "Level \(n), \(stars) stars")
                : String(localized: "Level \(n)")
            container.accessibilityTraits = .button
        } else {
            container.accessibilityLabel = String(localized: "Level \(n), locked")
            container.accessibilityTraits = [.button, .notEnabled]
        }

        if unlocked {
            // Soft glow halo behind current level
            if isCurrent {
                let halo = SKShapeNode(circleOfRadius: levelDotRadius + 18)
                halo.fillColor = UIColor(hex: "#FBCFE8").withAlphaComponent(0.5)
                halo.strokeColor = .clear
                halo.glowWidth = 14
                halo.blendMode = .add
                halo.zPosition = -1
                container.addChild(halo)
                halo.run(.repeatForever(.sequence([
                    .group([.scale(to: 1.18, duration: 1.0),
                            .fadeAlpha(to: 0.85, duration: 1.0)]),
                    .group([.scale(to: 1.0, duration: 1.0),
                            .fadeAlpha(to: 0.4, duration: 1.0)])
                ])))
            }

            // Drop shadow
            let shadow = SKShapeNode(circleOfRadius: levelDotRadius + 2)
            shadow.fillColor = UIColor(white: 0, alpha: 0.20)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -3)
            shadow.zPosition = 0
            container.addChild(shadow)

            // White outer ring
            let ring = SKShapeNode(circleOfRadius: levelDotRadius + 3)
            ring.fillColor = .white
            ring.strokeColor = .clear
            ring.zPosition = 1
            container.addChild(ring)

            // Pink body
            let config = Levels.config(for: n)
            let body = SKShapeNode(circleOfRadius: levelDotRadius)
            switch config.difficulty {
            case .normal:
                body.fillColor = UIColor(hex: "#EC4899")
            case .hard:
                body.fillColor = UIColor(hex: "#F97316")
            case .superHard:
                body.fillColor = UIColor(hex: "#7C3AED")
            case .crownChallenge:
                body.fillColor = UIColor(hex: "#0F172A")
            }
            body.strokeColor = Persistence.highContrast ? .white : UIColor(hex: "#BE185D")
            body.lineWidth = Persistence.highContrast ? 3 : 1.5
            body.zPosition = 2
            container.addChild(body)

            // Top highlight
            let hl = SKShapeNode(ellipseOf: CGSize(width: levelDotRadius * 1.0,
                                                    height: levelDotRadius * 0.45))
            hl.fillColor = UIColor.white.withAlphaComponent(0.55)
            hl.strokeColor = .clear
            hl.position = CGPoint(x: 0, y: levelDotRadius * 0.3)
            hl.zPosition = 3
            container.addChild(hl)

            // Number
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "\(n)"
            label.fontSize = 22
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -1)
            label.zPosition = 4
            container.addChild(label)

            if n >= 100 {
                let crown = Icons.sprite(Icons.Name.crown,
                                         size: 15,
                                         weight: .heavy,
                                         tint: UIColor(hex: "#FACC15"))
                crown.position = CGPoint(x: 0, y: levelDotRadius + 4)
                crown.zPosition = 6
                container.addChild(crown)

                let premium = SKShapeNode(circleOfRadius: levelDotRadius + 8)
                premium.fillColor = .clear
                premium.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.75)
                premium.lineWidth = 2
                premium.glowWidth = 7
                premium.zPosition = 1.5
                container.addChild(premium)
            }

            if config.difficulty != .normal {
                let tag = SKShapeNode(rectOf: CGSize(width: 38, height: 16), cornerRadius: 8)
                tag.fillColor = UIColor.white.withAlphaComponent(0.92)
                tag.strokeColor = UIColor(white: 0, alpha: 0.12)
                tag.lineWidth = 0.8
                tag.position = CGPoint(x: 0, y: levelDotRadius + 10)
                tag.zPosition = 5
                container.addChild(tag)

                let tagLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                switch config.difficulty {
                case .hard:
                    tagLabel.text = String(localized: "HARD")
                    tagLabel.fontColor = UIColor(hex: "#C2410C")
                case .superHard:
                    tagLabel.text = String(localized: "SUPER")
                    tagLabel.fontColor = UIColor(hex: "#6D28D9")
                case .crownChallenge:
                    tagLabel.text = String(localized: "CROWN")
                    tagLabel.fontColor = UIColor(hex: "#92400E")
                case .normal:
                    tagLabel.text = nil
                    tagLabel.fontColor = UIColor(hex: "#0F172A")
                }
                tagLabel.fontSize = 8
                tagLabel.verticalAlignmentMode = .center
                tagLabel.horizontalAlignmentMode = .center
                tag.addChild(tagLabel)
            }

            // Stars beneath the circle if completed
            if stars > 0 {
                let row = makeStarRow(filled: stars, size: 9)
                row.position = CGPoint(x: 0, y: -levelDotRadius - 14)
                row.zPosition = 4
                container.addChild(row)
            }

            // Mastery medals — small chips orbiting the top of the level node.
            // Subtle so they don't overpower the star row, but visible enough
            // to be a reason to replay a won level.
            let medals = Persistence.medalsForLevel(n)
            if medals.count > 0 {
                let row = makeMedalsRow(medals: medals)
                row.position = CGPoint(x: 0, y: levelDotRadius + 22)
                row.zPosition = 5
                container.addChild(row)
            }
        } else {
            // Locked: soft pastel circle with a crisp SF Symbol lock
            let shadow = SKShapeNode(circleOfRadius: lockedDotRadius + 1)
            shadow.fillColor = UIColor(white: 0, alpha: 0.15)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -2)
            container.addChild(shadow)

            let body = SKShapeNode(circleOfRadius: lockedDotRadius)
            body.fillColor = UIColor(hex: "#F9A8D4").withAlphaComponent(0.85)
            body.strokeColor = .white
            body.lineWidth = 2
            container.addChild(body)

            let lock = Icons.sprite("lock.fill", size: 18,
                                    tint: UIColor.white.withAlphaComponent(0.92))
            container.addChild(lock)
        }

        return container
    }

    /// Tight horizontal row of up to three medal chips. Each chip stays in its
    /// slot whether earned or not so the player can see what's still attainable
    /// — and chips fade out (instead of vanishing) when not earned.
    func makeMedalsRow(medals: Persistence.MedalSet) -> SKNode {
        let row = SKNode()
        let chips: [(emoji: String, earned: Bool, color: UIColor)] = [
            ("🛡", medals.noBoosters,   UIColor(hex: "#22D3EE")),
            ("⏱", medals.movesToSpare,  UIColor(hex: "#34D399")),
            ("🎯", medals.overshotGoal, UIColor(hex: "#F472B6"))
        ]
        let spacing: CGFloat = 18
        for (idx, chip) in chips.enumerated() where chip.earned {
            let x = -spacing + CGFloat(idx) * spacing
            let bg = SKShapeNode(circleOfRadius: 8)
            bg.fillColor = chip.color.withAlphaComponent(0.92)
            bg.strokeColor = .white
            bg.lineWidth = 1
            bg.position = CGPoint(x: x, y: 0)
            row.addChild(bg)

            let label = SKLabelNode(text: chip.emoji)
            label.fontSize = 9
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -1)
            bg.addChild(label)
        }
        return row
    }

    func makeStarRow(filled: Int, size: CGFloat) -> SKNode {
        let row = SKNode()
        let spacing: CGFloat = size * 2.6
        for i in 0..<3 {
            let x = CGFloat(i) * spacing - spacing
            let lit = i < filled
            let star = SKShapeNode(path: starPath(size: size * 2))
            star.fillColor = lit ? UIColor(hex: "#FBBF24") : UIColor(white: 1, alpha: 0.5)
            star.strokeColor = lit ? UIColor(hex: "#B45309") : UIColor(white: 0, alpha: 0.2)
            star.lineWidth = 0.8
            star.position = CGPoint(x: x, y: 0)
            row.addChild(star)
        }
        return row
    }

    func starPath(size: CGFloat) -> CGPath {
        let p = UIBezierPath()
        let outer = size / 2
        let inner = outer * 0.42
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let theta = -CGFloat.pi / 2 + CGFloat(i) * (.pi / 5)
            let pt = CGPoint(x: r * cos(theta), y: r * sin(theta))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        return p.cgPath
    }

    // MARK: - Avatar marker (tear-drop pin on current level)

    func placeAvatarMarker() {
        let n = Persistence.currentLevel
        guard n >= 1, n <= levelCount, let p = levelPositions[n] else { return }

        let pin = SKNode()
        pin.zPosition = 12
        pin.name = "lvl:\(n)"

        // Soft drop shadow on the dirt below the pin
        let groundShadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 12))
        groundShadow.fillColor = UIColor(white: 0, alpha: 0.22)
        groundShadow.strokeColor = .clear
        groundShadow.position = CGPoint(x: 0, y: -34)
        pin.addChild(groundShadow)

        // Tear-drop pin background
        let pinW: CGFloat = 52
        let pinH: CGFloat = 68
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: -pinH / 2))
        path.addQuadCurve(to: CGPoint(x: pinW / 2, y: 0),
                          controlPoint: CGPoint(x: pinW / 2, y: -pinH / 2 + 14))
        path.addArc(withCenter: CGPoint(x: 0, y: 4),
                    radius: pinW / 2,
                    startAngle: 0,
                    endAngle: .pi,
                    clockwise: true)
        path.addQuadCurve(to: CGPoint(x: 0, y: -pinH / 2),
                          controlPoint: CGPoint(x: -pinW / 2, y: -pinH / 2 + 14))
        path.close()

        let body = SKShapeNode(path: path.cgPath)
        body.fillColor = UIColor(hex: "#EC4899")
        body.strokeColor = .white
        body.lineWidth = 3
        pin.addChild(body)

        // White circular "frame" inside the pin where the character sits
        let frame = SKShapeNode(circleOfRadius: pinW / 2 - 4)
        frame.fillColor = UIColor(hex: "#FBCFE8")
        frame.strokeColor = UIColor.white.withAlphaComponent(0.85)
        frame.lineWidth = 1
        frame.position = CGPoint(x: 0, y: 6)
        pin.addChild(frame)

        // Chick character inside (cheap, on-brand)
        let face = SKLabelNode(text: "🐥")
        face.fontSize = 32
        face.verticalAlignmentMode = .center
        face.horizontalAlignmentMode = .center
        face.position = CGPoint(x: 0, y: 4)
        pin.addChild(face)

        // Position the pin sitting *on* the level dot — like Candy Crush.
        pin.position = CGPoint(x: p.x, y: p.y + 12)
        world.addChild(pin)
        avatarMarker = pin

        // Bobbing on the dot
        pin.run(.repeatForever(.sequence([
            .group([.moveBy(x: 0, y: 4, duration: 0.9),
                    .scale(to: 1.02, duration: 0.9)]),
            .group([.moveBy(x: 0, y: -4, duration: 0.9),
                    .scale(to: 1.0, duration: 0.9)])
        ])))
    }
}
