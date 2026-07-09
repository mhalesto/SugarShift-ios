import SpriteKit
import UIKit

/// Centred glass overlay shown at end of level (win or lose). Animates in,
/// reports back which button was tapped via the closures.
final class EndLevelCard: SKNode {

    struct MoveBonus {
        let moves: Int
        let points: Int
    }

    enum Outcome {
        case win(stars: Int, score: Int, targetText: String, moveBonus: MoveBonus?)
        case lose(score: Int, targetText: String, message: String, recommendation: String)
    }

    struct BonusOffer {
        let title: String
        let subtitle: String
        let buttonText: String
        let enabled: Bool
    }

    struct Breakdown {
        let score: Int
        let moveBonus: MoveBonus?
        let objective: String
        let rewards: [String]
        let threeStarReward: String?
        let newUnlock: String?
    }

    var onPrimary: (() -> Void)?  // "Next Level" or "Retry"
    var onSecondary: (() -> Void)? // "Choose level" — returns to the level map
    var onBonus: (() -> Void)?
    var onRetryForStars: (() -> Void)?
    var onRating: ((Persistence.LevelRating) -> Void)?
    var onShare: (() -> Void)?    // Daily challenge result share sheet

    private let outcome: Outcome
    private let bonusOffer: BonusOffer?
    private let breakdown: Breakdown?
    private let canRetryForStars: Bool
    private let showShareButton: Bool
    private let showRatingRow: Bool
    private var existingRating: Persistence.LevelRating?
    private let medals: Persistence.MedalSet
    private let cardSize: CGSize
    private static let bonusOfferHeight: CGFloat = 72
    private static let ratingRowHeight: CGFloat = 74
    private weak var ratingPromptLabel: SKLabelNode?
    private weak var thumbsUpButton: SKShapeNode?
    private weak var thumbsDownButton: SKShapeNode?
    private weak var bonusRow: SKShapeNode?
    private weak var bonusButton: SKShapeNode?
    private weak var bonusTitleLabel: SKLabelNode?
    private weak var bonusSubtitleLabel: SKLabelNode?
    private weak var bonusButtonLabel: SKLabelNode?
    private var bonusOriginalButtonText: String?
    private var bonusIsPending = false

    init(outcome: Outcome,
         sceneSize: CGSize,
         bonusOffer: BonusOffer? = nil,
         breakdown: Breakdown? = nil,
         canRetryForStars: Bool = false,
         showRatingRow: Bool = false,
         existingRating: Persistence.LevelRating? = nil,
         medals: Persistence.MedalSet = .none,
         showShareButton: Bool = false) {
        self.outcome = outcome
        self.bonusOffer = bonusOffer
        self.breakdown = breakdown
        self.canRetryForStars = canRetryForStars
        self.showRatingRow = showRatingRow
        self.existingRating = existingRating
        self.medals = medals
        self.showShareButton = showShareButton
        let hasMoveBonus: Bool = {
            if case .win(_, _, _, let moveBonus) = outcome {
                return moveBonus != nil
            }
            return false
        }()
        let isLoss: Bool = {
            if case .lose = outcome { return true }
            return false
        }()
        let breakdownRowCount: Int = {
            guard let breakdown else { return 0 }
            var count = 1
            if breakdown.moveBonus != nil { count += 1 }
            if !breakdown.rewards.isEmpty { count += 1 }
            if breakdown.threeStarReward != nil { count += 1 }
            if breakdown.newUnlock != nil { count += 1 }
            return count
        }()
        let hasBreakdown = breakdownRowCount > 0
        let rowExtra = CGFloat(max(0, breakdownRowCount - 5)) * 24
        let medalExtra: CGFloat = medals.count > 0 ? 28 : 0
        let ratingExtra: CGFloat = showRatingRow ? Self.ratingRowHeight + 18 : 0
        let baseHeight: CGFloat = {
            let core: CGFloat
            if hasBreakdown {
                core = (bonusOffer == nil ? 500 : 580) + rowExtra
            } else if isLoss {
                core = bonusOffer == nil ? 382 : 446
            } else {
                core = hasMoveBonus ? 390 : 360
            }
            return core + medalExtra + ratingExtra
        }()
        self.cardSize = CGSize(width: min(sceneSize.width - 40, 320),
                               height: min(sceneSize.height - 64, baseHeight))
        super.init()
        self.zPosition = 2000
        build(sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func build(sceneSize: CGSize) {
        // Dimming scrim covering the entire scene (full-screen tap-blocker)
        let scrim = SKShapeNode(rectOf: sceneSize)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.position = .zero
        scrim.zPosition = 0
        scrim.name = "endLevelScrim"
        addChild(scrim)
        scrim.alpha = 0
        scrim.run(.fadeAlpha(to: 1.0, duration: 0.25))

        // Card background
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 22)
        card.fillColor = .white
        card.strokeColor = UIColor(hex: "#E2E8F0")
        card.lineWidth = 1
        card.position = .zero
        card.zPosition = 1
        card.alpha = 0
        card.setScale(0.5)
        addChild(card)

        // Title
        let isWin: Bool = {
            if case .win = outcome { return true }
            return false
        }()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = isWin ? String(localized: "Level complete!") : String(localized: "Out of moves")
        title.fontSize = 22
        title.fontColor = isWin ? UIColor(hex: "#10B981") : UIColor(hex: "#EF4444")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: cardSize.height / 2 - 38)
        card.addChild(title)

        // Stars (3 slots, lit based on outcome)
        let starCount: Int = {
            if case .win(let s, _, _, _) = outcome { return s }
            return 0
        }()
        let top = cardSize.height / 2
        let bottom = -cardSize.height / 2
        let hasBreakdown = breakdown != nil
        let hasBonusOffer = bonusOffer != nil
        let starY = top - 108
        addStars(to: card, lit: starCount, y: starY)

        if isWin {
            let mastery = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            mastery.text = starCount >= 3 ? String(localized: "Perfect clear") : String(localized: "\(max(1, starCount))/3 stars earned")
            mastery.fontSize = 12
            mastery.fontColor = starCount >= 3 ? UIColor(hex: "#10B981") : UIColor(hex: "#64748B")
            mastery.verticalAlignmentMode = .center
            mastery.horizontalAlignmentMode = .center
            mastery.position = CGPoint(x: 0, y: starY - 46)
            card.addChild(mastery)

            if medals.count > 0 {
                let medalRow = makeMedalRow(medals: medals)
                medalRow.name = "medalRow"
                medalRow.position = CGPoint(x: 0, y: starY - 66)
                card.addChild(medalRow)
            }
        }

        // Score / target
        let scoreLine = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        scoreLine.name = "scoreLine"
        scoreLine.fontSize = hasBreakdown ? (medals.count > 0 ? 29 : 30) : 32
        scoreLine.fontColor = UIColor(hex: "#0F172A")
        scoreLine.verticalAlignmentMode = .center
        scoreLine.horizontalAlignmentMode = .center
        let scoreY: CGFloat = {
            guard hasBreakdown else { return 0 }
            if medals.count > 0 {
                return top - (hasBonusOffer ? 206 : 222)
            }
            return top - (hasBonusOffer ? 180 : 186)
        }()
        scoreLine.position = CGPoint(x: 0, y: scoreY)
        switch outcome {
        case .win(_, let score, _, _), .lose(let score, _, _, _):
            scoreLine.text = "\(score)"
        }
        card.addChild(scoreLine)

        let targetLine = SKLabelNode(fontNamed: "AvenirNext-Medium")
        targetLine.name = "targetLine"
        targetLine.fontSize = 13
        targetLine.fontColor = UIColor(hex: "#475569")
        targetLine.verticalAlignmentMode = .center
        targetLine.horizontalAlignmentMode = .center
        switch outcome {
        case .win(_, _, let targetText, _), .lose(_, let targetText, _, _):
            targetLine.text = targetText
        }
        targetLine.position = CGPoint(x: 0, y: scoreY - 30)
        card.addChild(targetLine)

        if case .lose(_, _, let message, let recommendation) = outcome {
            let feedback = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            feedback.text = message
            feedback.fontSize = 12
            feedback.fontColor = UIColor(hex: "#B91C1C")
            feedback.verticalAlignmentMode = .center
            feedback.horizontalAlignmentMode = .center
            feedback.position = CGPoint(x: 0, y: bonusOffer == nil ? -58 : -48)
            fitLabel(feedback, maxWidth: cardSize.width - 70, minFontSize: 10)
            card.addChild(feedback)

            let tip = SKLabelNode(fontNamed: "AvenirNext-Medium")
            tip.text = recommendation
            tip.fontSize = 11
            tip.fontColor = UIColor(hex: "#475569")
            tip.verticalAlignmentMode = .center
            tip.horizontalAlignmentMode = .center
            tip.position = CGPoint(x: 0, y: bonusOffer == nil ? -79 : -68)
            fitLabelOrTruncate(tip, maxWidth: cardSize.width - 70, minFontSize: 9.5)
            card.addChild(tip)
        }

        if !hasBreakdown, case .win(_, _, _, let moveBonus?) = outcome {
            addMoveBonus(moveBonus, to: card, y: -58)
        }

        var breakdownBottom: CGFloat?
        if let breakdown {
            let boxH = breakdownBoxHeight(for: breakdown)
            let breakdownY = targetLine.position.y - 26 - boxH / 2
            addBreakdown(breakdown, to: card, y: breakdownY)
            breakdownBottom = breakdownY - boxH / 2
        }

        let compactBonusActions = hasBreakdown && hasBonusOffer
        let usesRatingFooterStack = isWin && showRatingRow
        let primaryY = bottom + {
            if usesRatingFooterStack {
                if compactBonusActions { return CGFloat(144) }
                if hasBreakdown { return CGFloat(148) }
                return bonusOffer == nil ? CGFloat(126) : CGFloat(120)
            }
            return compactBonusActions ? CGFloat(86) : (hasBreakdown ? CGFloat(96) : (bonusOffer == nil ? CGFloat(90) : CGFloat(78)))
        }()
        let secondaryY = bottom + {
            if usesRatingFooterStack { return CGFloat(76) }
            return compactBonusActions ? CGFloat(32) : CGFloat(36)
        }()
        let lossFooterY = bottom + (hasBonusOffer ? 34 : 42)

        if let bonusOffer {
            let preferredY = hasBreakdown ? bottom + 196 : (isWin ? primaryY + 78 : lossFooterY + 66)
            let minGap: CGFloat = 12
            let primaryTop = isWin ? primaryY + 25 : lossFooterY + 18
            var offerY = preferredY
            if let breakdownBottom {
                offerY = min(offerY, breakdownBottom - minGap - Self.bonusOfferHeight / 2)
            }
            offerY = max(offerY, primaryTop + minGap + Self.bonusOfferHeight / 2)
            addBonusOffer(bonusOffer, to: card, y: offerY)
        }

        if !isWin {
            let rowW = cardSize.width - 56
            let gap: CGFloat = 8
            let buttonSize = CGSize(width: (rowW - gap) / 2, height: 36)
            let retry = makeFooterButton(text: String(localized: "Retry"),
                                         icon: "↻",
                                         fill: UIColor(hex: "#F472B6"),
                                         textColor: .white,
                                         width: buttonSize.width,
                                         height: buttonSize.height,
                                         name: "primaryBtn")
            retry.position = CGPoint(x: -buttonSize.width / 2 - gap / 2, y: lossFooterY)
            card.addChild(retry)

            let levels = makeFooterButton(text: String(localized: "Levels"),
                                          icon: "☰",
                                          fill: UIColor(hex: "#F8FAFC"),
                                          textColor: UIColor(hex: "#475569"),
                                          width: buttonSize.width,
                                          height: buttonSize.height,
                                          name: "secondaryBtn",
                                          stroke: UIColor(hex: "#CBD5E1"))
            levels.position = CGPoint(x: buttonSize.width / 2 + gap / 2, y: lossFooterY)
            card.addChild(levels)
            animateCardEntrance(card)
            return
        }

        // Primary button (Next / Retry). A daily-challenge win shares the row
        // with the Share button — the share is the growth loop, keep it big.
        if showShareButton {
            let rowW = cardSize.width - 56
            let gap: CGFloat = 10
            let primaryW = (rowW - gap) * 0.56
            let shareW = rowW - gap - primaryW
            let primary = makeButton(text: String(localized: "Next Level"),
                                     fill: UIColor(hex: "#F472B6"),
                                     textColor: .white,
                                     width: primaryW,
                                     height: 50,
                                     name: "primaryBtn")
            primary.position = CGPoint(x: -(shareW + gap) / 2, y: primaryY)
            card.addChild(primary)

            let share = makeButton(text: String(localized: "Share 📤"),
                                   fill: UIColor(hex: "#10B981"),
                                   textColor: .white,
                                   width: shareW,
                                   height: 50,
                                   name: "shareBtn")
            share.position = CGPoint(x: (primaryW + gap) / 2, y: primaryY)
            card.addChild(share)
        } else {
            let primary = makeButton(text: isWin ? String(localized: "Next Level") : String(localized: "Retry"),
                                     fill: UIColor(hex: "#F472B6"),
                                     textColor: .white,
                                     width: cardSize.width - 56,
                                     height: 50,
                                     name: "primaryBtn")
            primary.position = CGPoint(x: 0, y: primaryY)
            card.addChild(primary)
        }

        if canRetryForStars {
            let rowW = cardSize.width - 56
            let gap: CGFloat = 10
            let retryW = (rowW - gap) * 0.58
            let levelsW = rowW - gap - retryW
            let retry = makeButton(text: String(localized: "Retry for 3 stars"),
                                   fill: UIColor(hex: "#FBBF24"),
                                   textColor: UIColor(hex: "#0F172A"),
                                   width: retryW,
                                   height: 36,
                                   name: "retryStarsBtn")
            retry.position = CGPoint(x: -(levelsW + gap) / 2, y: secondaryY)
            card.addChild(retry)

            let secondary = makeButton(text: String(localized: "Choose level"),
                                       fill: UIColor(white: 0, alpha: 0.06),
                                       textColor: UIColor(hex: "#0F172A"),
                                       width: levelsW,
                                       height: 36,
                                       name: "secondaryBtn")
            secondary.position = CGPoint(x: (retryW + gap) / 2, y: secondaryY)
            card.addChild(secondary)
        } else {
            let secondary = makeButton(text: String(localized: "Choose level"),
                                       fill: UIColor(white: 0, alpha: 0.06),
                                       textColor: UIColor(hex: "#0F172A"),
                                       width: cardSize.width - 56,
                                       height: bonusOffer == nil ? 42 : 36,
                                       name: "secondaryBtn")
            secondary.position = CGPoint(x: 0, y: secondaryY)
            card.addChild(secondary)
        }

        animateCardEntrance(card)

        // Confetti for wins with stars
        if isWin, starCount > 0 {
            let confetti = Effects.makeConfetti(width: cardSize.width)
            confetti.position = CGPoint(x: 0, y: cardSize.height / 2 + 8)
            card.addChild(confetti)
            confetti.run(.sequence([.wait(forDuration: 2.4), .removeFromParent()]))
        }

        if showRatingRow {
            let ratingY = bottom + 28
            addRatingRow(to: card, y: ratingY)
        }
    }

    // MARK: - Mastery medals row

    /// Three small medal chips: 🛡 no booster, ⏱ moves to spare, 🎯 goal overshot.
    /// Earned medals are gold; unearned are faded grey.
    private func makeMedalRow(medals: Persistence.MedalSet) -> SKNode {
        let row = SKNode()
        let chips: [(label: String, earned: Bool, tint: UIColor)] = [
            ("🛡", medals.noBoosters,   UIColor(hex: "#22D3EE")),
            ("⏱",  medals.movesToSpare, UIColor(hex: "#34D399")),
            ("🎯", medals.overshotGoal, UIColor(hex: "#F472B6"))
        ]
        let spacing: CGFloat = 56
        for (idx, chip) in chips.enumerated() {
            let x = -spacing + CGFloat(idx) * spacing
            let bg = SKShapeNode(circleOfRadius: 13)
            bg.fillColor = chip.earned ? chip.tint.withAlphaComponent(0.92) : UIColor(white: 0, alpha: 0.08)
            bg.strokeColor = chip.earned ? .white : UIColor(white: 0, alpha: 0.18)
            bg.lineWidth = chip.earned ? 1.5 : 1
            bg.position = CGPoint(x: x, y: 0)
            row.addChild(bg)

            let emoji = SKLabelNode(text: chip.label)
            emoji.fontSize = 14
            emoji.verticalAlignmentMode = .center
            emoji.horizontalAlignmentMode = .center
            emoji.position = CGPoint(x: 0, y: -1)
            emoji.alpha = chip.earned ? 1.0 : 0.35
            bg.addChild(emoji)
        }
        return row
    }

    // MARK: - Level rating row

    private func addRatingRow(to parent: SKNode, y: CGFloat) {
        let prompt = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        prompt.text = existingRating == nil ? String(localized: "How was this level?") : String(localized: "Thanks!")
        prompt.fontSize = 11
        prompt.fontColor = UIColor(hex: "#64748B")
        prompt.verticalAlignmentMode = .center
        prompt.horizontalAlignmentMode = .center
        prompt.position = CGPoint(x: -38, y: y)
        parent.addChild(prompt)
        ratingPromptLabel = prompt

        let upBtn = makeThumbButton(symbol: "👍",
                                    selected: existingRating == .thumbsUp,
                                    enabled: existingRating == nil,
                                    name: "thumbsUp")
        upBtn.position = CGPoint(x: 38, y: y)
        parent.addChild(upBtn)
        thumbsUpButton = upBtn

        let downBtn = makeThumbButton(symbol: "👎",
                                      selected: existingRating == .thumbsDown,
                                      enabled: existingRating == nil,
                                      name: "thumbsDown")
        downBtn.position = CGPoint(x: 76, y: y)
        parent.addChild(downBtn)
        thumbsDownButton = downBtn
    }

    private func makeThumbButton(symbol: String,
                                 selected: Bool,
                                 enabled: Bool,
                                 name: String) -> SKShapeNode {
        let btn = SKShapeNode(circleOfRadius: 14)
        btn.fillColor = selected
            ? UIColor(hex: "#10B981").withAlphaComponent(0.92)
            : UIColor(white: 0, alpha: 0.05)
        btn.strokeColor = selected ? .white : UIColor(white: 0, alpha: 0.15)
        btn.lineWidth = 1
        btn.name = enabled ? name : nil

        let label = SKLabelNode(text: symbol)
        label.fontSize = 14
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -1)
        label.alpha = enabled ? 1.0 : 0.5
        btn.addChild(label)
        return btn
    }

    /// Mark a thumb as selected and disable further taps. Called when the
    /// scene records the rating.
    func markRated(_ rating: Persistence.LevelRating) {
        existingRating = rating
        ratingPromptLabel?.text = String(localized: "Thanks!")
        let up = thumbsUpButton
        let down = thumbsDownButton
        up?.name = nil
        down?.name = nil
        if rating == .thumbsUp {
            up?.fillColor = UIColor(hex: "#10B981").withAlphaComponent(0.92)
            up?.strokeColor = .white
            down?.fillColor = UIColor(white: 0, alpha: 0.05)
        } else {
            down?.fillColor = UIColor(hex: "#EF4444").withAlphaComponent(0.92)
            down?.strokeColor = .white
            up?.fillColor = UIColor(white: 0, alpha: 0.05)
        }
        up?.run(.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1.0, duration: 0.10)]))
        down?.run(.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1.0, duration: 0.10)]))
    }

    private func addMoveBonus(_ bonus: MoveBonus, to parent: SKNode, y: CGFloat) {
        let rowW = cardSize.width - 88
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: 28), cornerRadius: 14)
        row.fillColor = UIColor(hex: "#FEF3C7").withAlphaComponent(0.9)
        row.strokeColor = UIColor(hex: "#FBBF24").withAlphaComponent(0.9)
        row.lineWidth = 1
        row.position = CGPoint(x: 0, y: y)
        parent.addChild(row)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "\(bonus.moves) moves left  +\(bonus.points)"
        label.fontSize = 13
        label.fontColor = UIColor(hex: "#92400E")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        row.addChild(label)
    }

    private func addBonusOffer(_ offer: BonusOffer, to parent: SKNode, y: CGFloat) {
        let rowW = cardSize.width - 56
        let rowH = Self.bonusOfferHeight
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: rowH), cornerRadius: 18)
        row.fillColor = UIColor(hex: "#F0FDFA")
        row.strokeColor = UIColor(hex: "#22D3EE").withAlphaComponent(0.75)
        row.lineWidth = 1.2
        row.position = CGPoint(x: 0, y: y)
        row.name = offer.enabled ? "bonusBtn" : "bonusDisabled"
        parent.addChild(row)
        bonusRow = row
        bonusOriginalButtonText = offer.buttonText

        let btnW = min(CGFloat(98), rowW * 0.36)
        let btnH: CGFloat = 34
        let btnX = rowW / 2 - btnW / 2 - 12
        let textX = -rowW / 2 + 16
        let textMaxW = max(CGFloat(104), rowW - btnW - 48)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.name = "bonusTitleLabel"
        title.text = offer.title
        title.fontSize = 14
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: textX, y: 16)
        fitLabel(title, maxWidth: textMaxW, minFontSize: 11)
        row.addChild(title)
        bonusTitleLabel = title

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.name = "bonusSubtitleLabel"
        subtitle.text = offer.subtitle
        subtitle.fontSize = 10.5
        subtitle.fontColor = UIColor(hex: "#334155")
        subtitle.verticalAlignmentMode = .center
        subtitle.horizontalAlignmentMode = .left
        subtitle.position = CGPoint(x: textX, y: -12)
        fitLabelOrTruncate(subtitle, maxWidth: textMaxW, minFontSize: 9)
        row.addChild(subtitle)
        bonusSubtitleLabel = subtitle

        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        btn.fillColor = offer.enabled ? UIColor(hex: "#10B981") : UIColor(white: 0, alpha: 0.08)
        btn.strokeColor = .clear
        btn.position = CGPoint(x: btnX, y: 0)
        btn.name = offer.enabled ? "bonusBtn" : "bonusDisabled"
        row.addChild(btn)
        bonusButton = btn

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = "bonusButtonLabel"
        label.text = offer.buttonText
        label.fontSize = 13
        label.fontColor = offer.enabled ? .white : UIColor(white: 0, alpha: 0.4)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        fitLabel(label, maxWidth: btnW - 16, minFontSize: 10)
        btn.addChild(label)
        bonusButtonLabel = label
    }

    func beginBonusRequest() {
        guard !bonusIsPending else { return }
        bonusIsPending = true
        bonusRow?.name = "bonusPending"
        bonusButton?.name = "bonusPending"
        bonusRow?.fillColor = UIColor(hex: "#EFF6FF")
        bonusRow?.strokeColor = UIColor(hex: "#60A5FA").withAlphaComponent(0.85)
        bonusButton?.fillColor = UIColor(hex: "#3B82F6")
        bonusButtonLabel?.text = String(localized: "Opening...")
        bonusButtonLabel?.fontColor = .white
        bonusSubtitleLabel?.text = String(localized: "Opening ad...")
        bonusSubtitleLabel?.fontColor = UIColor(hex: "#2563EB")
        refitBonusOfferLabels()
        if let bonusButton {
            bonusButton.removeAction(forKey: "bonusPulse")
            bonusButton.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.74, duration: 0.45),
                .fadeAlpha(to: 1.0, duration: 0.45)
            ])), withKey: "bonusPulse")
        }
    }

    func markBonusCompleted(title: String, subtitle: String, buttonText: String = "Claimed") {
        bonusIsPending = false
        bonusRow?.name = "bonusClaimed"
        bonusButton?.name = "bonusClaimed"
        bonusRow?.fillColor = UIColor(hex: "#FFFBEB")
        bonusRow?.strokeColor = UIColor(hex: "#FACC15").withAlphaComponent(0.95)
        bonusButton?.removeAction(forKey: "bonusPulse")
        bonusButton?.alpha = 1
        bonusButton?.fillColor = UIColor(hex: "#FACC15")
        bonusTitleLabel?.text = title
        bonusTitleLabel?.fontColor = UIColor(hex: "#92400E")
        bonusSubtitleLabel?.text = subtitle
        bonusSubtitleLabel?.fontColor = UIColor(hex: "#92400E")
        bonusButtonLabel?.text = buttonText
        bonusButtonLabel?.fontColor = UIColor(hex: "#0F172A")
        refitBonusOfferLabels()
    }

    func markBonusFailed() {
        bonusIsPending = false
        bonusRow?.name = "bonusBtn"
        bonusButton?.name = "bonusBtn"
        bonusRow?.fillColor = UIColor(hex: "#FFF7ED")
        bonusRow?.strokeColor = UIColor(hex: "#FB923C").withAlphaComponent(0.95)
        bonusButton?.removeAction(forKey: "bonusPulse")
        bonusButton?.alpha = 1
        bonusButton?.fillColor = UIColor(hex: "#10B981")
        bonusTitleLabel?.fontColor = UIColor(hex: "#0F172A")
        bonusSubtitleLabel?.text = String(localized: "Ad not completed. Try again")
        bonusSubtitleLabel?.fontColor = UIColor(hex: "#C2410C")
        bonusButtonLabel?.text = bonusOriginalButtonText ?? "Watch"
        bonusButtonLabel?.fontColor = .white
        refitBonusOfferLabels()
    }

    private func refitBonusOfferLabels() {
        let rowW = cardSize.width - 56
        let btnW = min(CGFloat(98), rowW * 0.36)
        let textMaxW = max(CGFloat(104), rowW - btnW - 48)
        if let bonusTitleLabel {
            fitLabelOrTruncate(bonusTitleLabel, maxWidth: textMaxW, minFontSize: 10.5)
        }
        if let bonusSubtitleLabel {
            fitLabelOrTruncate(bonusSubtitleLabel, maxWidth: textMaxW, minFontSize: 8.5)
        }
        if let bonusButtonLabel {
            fitLabel(bonusButtonLabel, maxWidth: btnW - 16, minFontSize: 9)
        }
    }

    private func addBreakdown(_ breakdown: Breakdown, to parent: SKNode, y: CGFloat) {
        let boxW = cardSize.width - 50
        let rows = breakdownRows(for: breakdown)
        let boxH = breakdownBoxHeight(for: breakdown)
        let box = SKShapeNode(rectOf: CGSize(width: boxW, height: boxH), cornerRadius: 14)
        box.fillColor = UIColor(hex: "#F8FAFC")
        box.strokeColor = UIColor(hex: "#E2E8F0")
        box.lineWidth = 1
        box.position = CGPoint(x: 0, y: y)
        parent.addChild(box)

        var rowY = boxH / 2 - 18
        for row in rows.prefix(7) {
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = row.0
            label.fontSize = 10
            label.fontColor = UIColor(hex: "#64748B")
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -boxW / 2 + 14, y: rowY)
            fitLabel(label, maxWidth: boxW * 0.32, minFontSize: 8)
            box.addChild(label)

            let value = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            value.text = row.1
            value.fontSize = 10
            value.fontColor = UIColor(hex: "#0F172A")
            value.verticalAlignmentMode = .center
            value.horizontalAlignmentMode = .right
            value.position = CGPoint(x: boxW / 2 - 14, y: rowY)
            fitLabelOrTruncate(value, maxWidth: boxW * 0.62, minFontSize: 8)
            box.addChild(value)
            rowY -= 20
        }
    }

    private func breakdownBoxHeight(for breakdown: Breakdown) -> CGFloat {
        CGFloat(max(3, breakdownRows(for: breakdown).count)) * 22 + 26
    }

    private func breakdownRows(for breakdown: Breakdown) -> [(String, String)] {
        var rows: [(String, String)] = [
            ("Objective", breakdown.objective)
        ]
        if let moveBonus = breakdown.moveBonus {
            rows.append((String(localized: "Move bonus"), String(localized: "\(moveBonus.moves) left  +\(moveBonus.points)")))
        }
        if !breakdown.rewards.isEmpty {
            rows.append(("Rewards", breakdown.rewards.joined(separator: " + ")))
        }
        if let threeStarReward = breakdown.threeStarReward {
            rows.append(("3-star", threeStarReward))
        }
        if let newUnlock = breakdown.newUnlock {
            rows.append(("Unlocked", newUnlock))
        }
        return rows
    }

    private func addStars(to parent: SKNode, lit: Int, y: CGFloat) {
        let spacing: CGFloat = 64
        for i in 0..<3 {
            let x = -spacing + CGFloat(i) * spacing
            let isLit = i < lit
            let star = makeStar(litFill: isLit, size: 44)
            star.position = CGPoint(x: x, y: y)
            parent.addChild(star)
            if isLit {
                // Stagger the pop-in
                star.alpha = 0
                star.setScale(0.3)
                star.run(.sequence([
                    .wait(forDuration: 0.3 + Double(i) * 0.18),
                    .group([
                        .fadeIn(withDuration: 0.2),
                        .sequence([
                            .scale(to: 1.25, duration: 0.18),
                            .scale(to: 1.0, duration: 0.12)
                        ])
                    ])
                ]))
            }
        }
    }

    private func makeStar(litFill: Bool, size: CGFloat) -> SKNode {
        let node = SKNode()
        let path = starPath(size: size)
        let body = SKShapeNode(path: path)
        body.fillColor = litFill ? UIColor(hex: "#FBBF24") : UIColor(white: 0, alpha: 0.1)
        body.strokeColor = litFill ? UIColor(hex: "#B45309") : UIColor(white: 0, alpha: 0.2)
        body.lineWidth = 1
        node.addChild(body)
        if litFill {
            let glow = SKShapeNode(circleOfRadius: size * 0.65)
            glow.fillColor = UIColor(hex: "#FDE68A").withAlphaComponent(0.5)
            glow.strokeColor = .clear
            glow.glowWidth = 8
            glow.blendMode = .add
            glow.zPosition = -1
            node.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .group([.scale(to: 1.15, duration: 1.2),
                        .fadeAlpha(to: 0.7, duration: 1.2)]),
                .group([.scale(to: 1.0, duration: 1.2),
                        .fadeAlpha(to: 0.4, duration: 1.2)])
            ])))
        }
        return node
    }

    private func starPath(size: CGFloat) -> CGPath {
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

    private func makeButton(text: String, fill: UIColor, textColor: UIColor,
                            width: CGFloat, height: CGFloat, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        btn.fillColor = fill
        btn.strokeColor = .clear
        btn.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        fitLabel(label, maxWidth: width - 18, minFontSize: 11)
        btn.addChild(label)
        btn.isAccessibilityElement = true
        btn.accessibilityLabel = text
        btn.accessibilityTraits = .button
        return btn
    }

    private func makeFooterButton(text: String,
                                  icon: String,
                                  fill: UIColor,
                                  textColor: UIColor,
                                  width: CGFloat,
                                  height: CGFloat,
                                  name: String,
                                  stroke: UIColor? = nil) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        btn.fillColor = fill
        btn.strokeColor = stroke ?? UIColor.white.withAlphaComponent(0.22)
        btn.lineWidth = stroke == nil ? 0 : 1
        btn.name = name

        let iconLabel = SKLabelNode(text: icon)
        iconLabel.fontSize = 15
        iconLabel.verticalAlignmentMode = .center
        iconLabel.horizontalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -width / 2 + 20, y: 0)
        btn.addChild(iconLabel)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 12.5
        label.fontColor = textColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 8, y: 0)
        fitLabel(label, maxWidth: width - 42, minFontSize: 10)
        btn.addChild(label)
        btn.isAccessibilityElement = true
        btn.accessibilityLabel = text
        btn.accessibilityTraits = .button
        return btn
    }

    private func animateCardEntrance(_ card: SKNode) {
        card.run(.group([
            .fadeIn(withDuration: 0.18),
            .sequence([
                .scale(to: 1.05, duration: 0.22),
                .scale(to: 1.0, duration: 0.12)
            ])
        ]))
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        while label.frame.width > maxWidth && label.fontSize > minFontSize {
            label.fontSize -= 0.5
        }
    }

    private func fitLabelOrTruncate(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        fitLabel(label, maxWidth: maxWidth, minFontSize: minFontSize)
        guard label.frame.width > maxWidth, var text = label.text, text.count > 4 else { return }
        while label.frame.width > maxWidth && text.count > 4 {
            text.removeLast()
            label.text = "\(text)..."
        }
    }

    /// Hit-test a tap point (in scene coords) and fire the matching callback.
    func handleTap(at scenePoint: CGPoint) -> Bool {
        let local = self.convert(scenePoint, from: self.parent ?? self)
        if let bonusRow, bonusRow.frame.insetBy(dx: -8, dy: -8).contains(local) {
            if bonusRow.name == "bonusBtn" {
                bounce(bonusButton ?? bonusRow)
                beginBonusRequest()
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onBonus?()
                }]))
                return true
            }
            if bonusRow.name == "bonusPending" || bonusRow.name == "bonusClaimed" || bonusRow.name == "bonusDisabled" {
                bounce(bonusButton ?? bonusRow)
                return true
            }
        }
        var n: SKNode? = atPoint(local)
        while let node = n {
            if node.name == "primaryBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onPrimary?()
                }]))
                return true
            }
            if node.name == "secondaryBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onSecondary?()
                }]))
                return true
            }
            if node.name == "shareBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onShare?()
                }]))
                return true
            }
            if node.name == "bonusBtn" {
                bounce(node)
                beginBonusRequest()
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onBonus?()
                }]))
                return true
            }
            if node.name == "bonusPending" || node.name == "bonusClaimed" {
                bounce(node)
                return true
            }
            if node.name == "bonusDisabled" {
                bounce(node)
                return true
            }
            if node.name == "retryStarsBtn" {
                bounce(node)
                run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in
                    self?.onRetryForStars?()
                }]))
                return true
            }
            if node.name == "thumbsUp" {
                bounce(node)
                onRating?(.thumbsUp)
                markRated(.thumbsUp)
                return true
            }
            if node.name == "thumbsDown" {
                bounce(node)
                onRating?(.thumbsDown)
                markRated(.thumbsDown)
                return true
            }
            n = node.parent
        }
        return true   // swallow taps that hit the scrim/card
    }

    func dismiss(_ completion: (() -> Void)? = nil) {
        run(.sequence([
            .group([.scale(to: 0.4, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent(),
            .run { completion?() }
        ]))
    }

    private func bounce(_ node: SKNode) {
        node.run(.sequence([
            .scale(to: 0.94, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }
}
