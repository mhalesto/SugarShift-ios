import SpriteKit
import UIKit

/// In-game shop. Wallet header, category tabs, and compact product pages.
final class ShopCard: SKNode {

    struct Item {
        enum Tab: String, CaseIterable {
            case earn
            case boosts
            case special
            case coins

            var title: String {
                switch self {
                case .earn: return "Earn"
                case .boosts: return "Boosts"
                case .special: return "Special"
                case .coins: return "Coins"
                }
            }
        }

        let id: String
        let emojiIcon: String?
        let symbolIcon: String?
        let iconBg: UIColor
        let iconTint: UIColor
        let title: String
        let subtitle: String
        let buttonText: String
        let buttonColor: UIColor
        let buttonTextColor: UIColor
        let enabled: Bool
        var tab: Tab = .boosts
        var isFeatured: Bool = false
        var progress: CGFloat? = nil
        var meterText: String? = nil
    }

    var onBuy: ((String) -> Void)?
    var onClose: (() -> Void)?

    private var allItems: [Item]
    private let availableTabs: [Item.Tab]
    private var selectedTab: Item.Tab
    private var walletLabel: SKLabelNode!
    private var cardNode: SKNode?
    private var tabBarNode: SKNode?
    private var contentNode: SKNode?
    private let cardSize: CGSize
    private let refreshItems: (() -> [Item])?

    init(items: [Item],
         walletCash: Int,
         sceneSize: CGSize,
         initialTab: Item.Tab = .boosts,
         refreshItems: (() -> [Item])? = nil) {
        allItems = items
        availableTabs = Self.tabs(for: items)
        selectedTab = availableTabs.contains(initialTab) ? initialTab : (availableTabs.first ?? .boosts)
        cardSize = Self.cardSize(for: items, sceneSize: sceneSize)
        self.refreshItems = refreshItems
        super.init()
        zPosition = 1500
        build(walletCash: walletCash, sceneSize: sceneSize)
        startRefreshTimerIfNeeded()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private static func tabs(for items: [Item]) -> [Item.Tab] {
        let present = Set(items.map(\.tab))
        let ordered = Item.Tab.allCases.filter { present.contains($0) }
        return ordered.isEmpty ? [.boosts] : ordered
    }

    private static func cardSize(for items: [Item], sceneSize: CGSize) -> CGSize {
        let width = min(sceneSize.width - 32, 350)
        let maxContentHeight = tabs(for: items)
            .map { tab in contentHeight(for: items.filter { $0.tab == tab }) }
            .max() ?? 240
        let desiredHeight = max(360, 166 + maxContentHeight)
        return CGSize(width: width, height: min(sceneSize.height - 82, desiredHeight))
    }

    private static func contentHeight(for items: [Item],
                                      regularHeight: CGFloat = 84,
                                      featureHeight: CGFloat = 106,
                                      gap: CGFloat = 10) -> CGFloat {
        var total: CGFloat = 0
        var regularCount = 0

        func addRow(_ height: CGFloat) {
            if total > 0 { total += gap }
            total += height
        }

        func flushRegulars() {
            guard regularCount > 0 else { return }
            addRow(regularHeight)
            regularCount = 0
        }

        for item in items {
            if item.isFeatured {
                flushRegulars()
                addRow(featureHeight)
            } else {
                regularCount += 1
                if regularCount == 2 {
                    flushRegulars()
                }
            }
        }
        flushRegulars()
        return total
    }

    private func build(walletCash: Int, sceneSize: CGSize) {
        let scrim = SKShapeNode(rectOf: sceneSize)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.zPosition = 0
        scrim.name = "shopScrim"
        scrim.alpha = 0
        addChild(scrim)
        scrim.run(.fadeAlpha(to: 1.0, duration: 0.18))

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 24)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.6)
        card.lineWidth = 1
        card.zPosition = 1
        card.alpha = 0
        card.setScale(0.7)
        addChild(card)
        cardNode = card
        card.run(.group([.fadeIn(withDuration: 0.18),
                         .scale(to: 1.0, duration: 0.22)]))

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "Shop")
        title.fontSize = 24
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -cardSize.width / 2 + 24, y: cardSize.height / 2 - 30)
        card.addChild(title)

        let walletW: CGFloat = 110
        let walletPill = SKShapeNode(rectOf: CGSize(width: walletW, height: 30), cornerRadius: 15)
        walletPill.fillColor = UIColor(hex: "#FEF3C7")
        walletPill.strokeColor = UIColor(hex: "#FFD700").withAlphaComponent(0.5)
        walletPill.lineWidth = 1
        walletPill.position = CGPoint(x: cardSize.width / 2 - 24 - walletW / 2,
                                      y: cardSize.height / 2 - 30)
        card.addChild(walletPill)

        let coin = makeCoin(diameter: 18)
        coin.position = CGPoint(x: -walletW / 2 + 16, y: 0)
        walletPill.addChild(coin)

        let wallet = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        wallet.text = "\(walletCash)"
        wallet.fontSize = 14
        wallet.fontColor = UIColor(hex: "#7C2D12")
        wallet.verticalAlignmentMode = .center
        wallet.horizontalAlignmentMode = .center
        wallet.position = CGPoint(x: 6, y: 0)
        walletPill.addChild(wallet)
        walletLabel = wallet

        let divider = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 1))
        divider.fillColor = UIColor(white: 0, alpha: 0.08)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: cardSize.height / 2 - 56)
        card.addChild(divider)

        renderTabs()
        renderContent()
        buildCloseButton(in: card)
    }

    private func startRefreshTimerIfNeeded() {
        guard refreshItems != nil else { return }
        run(.repeatForever(.sequence([
            .wait(forDuration: 1),
            .run { [weak self] in
                guard let self, let refreshItems = self.refreshItems else { return }
                self.allItems = refreshItems()
                self.renderContent()
            }
        ])), withKey: "shopCountdownRefresh")
    }

    private func renderTabs() {
        guard let cardNode else { return }
        tabBarNode?.removeFromParent()

        let bar = SKNode()
        tabBarNode = bar
        cardNode.addChild(bar)

        let gap: CGFloat = 6
        let stripW = cardSize.width - 40
        let tabW = (stripW - CGFloat(max(0, availableTabs.count - 1)) * gap) / CGFloat(max(1, availableTabs.count))
        let tabH: CGFloat = 28
        let y = cardSize.height / 2 - 82
        let startX = -stripW / 2 + tabW / 2

        for (index, tab) in availableTabs.enumerated() {
            let isSelected = tab == selectedTab
            let name = "shopTab:\(tab.rawValue)"
            let shell = SKShapeNode(rectOf: CGSize(width: tabW, height: tabH), cornerRadius: tabH / 2)
            shell.fillColor = isSelected ? UIColor(hex: "#0F172A") : UIColor(hex: "#F1F5F9")
            shell.strokeColor = isSelected ? UIColor(hex: "#0F172A") : UIColor(hex: "#CBD5E1")
            shell.lineWidth = 1
            shell.position = CGPoint(x: startX + CGFloat(index) * (tabW + gap), y: y)
            shell.name = name
            bar.addChild(shell)

            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = tab.title
            label.fontSize = 10.5
            label.fontColor = isSelected ? .white : UIColor(hex: "#475569")
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = name
            fitLabel(label, maxWidth: tabW - 10, minFontSize: 8)
            shell.addChild(label)

            shell.isAccessibilityElement = true
            shell.accessibilityLabel = tab.title
            shell.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func renderContent() {
        guard let cardNode else { return }
        contentNode?.removeFromParent()

        let content = SKNode()
        contentNode = content
        cardNode.addChild(content)

        let visibleItems = allItems.filter { $0.tab == selectedTab }
        let contentTop = cardSize.height / 2 - 112
        let contentBottom = -cardSize.height / 2 + 54
        let availableHeight = max(120, contentTop - contentBottom)
        let desiredHeight = max(1, Self.contentHeight(for: visibleItems))
        let scale = min(1, availableHeight / desiredHeight)
        let regularHeight = max(70, 84 * scale)
        let featureHeight = max(88, 106 * scale)
        let gap = max(7, 10 * scale)
        let sideInset: CGFloat = 16
        let horizontalGap: CGFloat = 10
        let tileW = (cardSize.width - sideInset * 2 - horizontalGap) / 2
        let featureW = cardSize.width - sideInset * 2
        var y = contentTop
        var pendingRegulars: [Item] = []

        func flushRegulars() {
            guard !pendingRegulars.isEmpty else { return }
            let rowItems = pendingRegulars
            pendingRegulars.removeAll()
            let centerY = y - regularHeight / 2
            if rowItems.count == 1 {
                buildTile(rowItems[0],
                          into: content,
                          at: CGPoint(x: 0, y: centerY),
                          size: CGSize(width: tileW, height: regularHeight))
            } else {
                let leftX = -cardSize.width / 2 + sideInset + tileW / 2
                let rightX = leftX + tileW + horizontalGap
                buildTile(rowItems[0],
                          into: content,
                          at: CGPoint(x: leftX, y: centerY),
                          size: CGSize(width: tileW, height: regularHeight))
                buildTile(rowItems[1],
                          into: content,
                          at: CGPoint(x: rightX, y: centerY),
                          size: CGSize(width: tileW, height: regularHeight))
            }
            y -= regularHeight + gap
        }

        for item in visibleItems {
            if item.isFeatured {
                flushRegulars()
                let centerY = y - featureHeight / 2
                buildFeatureTile(item,
                                 into: content,
                                 at: CGPoint(x: 0, y: centerY),
                                 size: CGSize(width: featureW, height: featureHeight))
                y -= featureHeight + gap
            } else {
                pendingRegulars.append(item)
                if pendingRegulars.count == 2 {
                    flushRegulars()
                }
            }
        }
        flushRegulars()
    }

    private func buildCloseButton(in card: SKNode) {
        let closeShell = SKShapeNode(rectOf: CGSize(width: 150, height: 32), cornerRadius: 16)
        closeShell.fillColor = UIColor(hex: "#F8FAFC")
        closeShell.strokeColor = UIColor(hex: "#CBD5E1")
        closeShell.lineWidth = 1
        closeShell.position = CGPoint(x: 0, y: -cardSize.height / 2 + 26)
        closeShell.name = "shopClose"
        card.addChild(closeShell)

        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = String(localized: "Close")
        close.fontSize = 14
        close.fontColor = UIColor(hex: "#475569")
        close.verticalAlignmentMode = .center
        close.horizontalAlignmentMode = .center
        close.name = "shopClose"
        closeShell.addChild(close)

        closeShell.isAccessibilityElement = true
        closeShell.accessibilityLabel = String(localized: "Close")
        closeShell.accessibilityTraits = .button
    }

    private func buildTile(_ item: Item, into parent: SKNode, at point: CGPoint, size: CGSize) {
        let tileName = item.enabled ? "shopBuy:\(item.id)" : "shopDisabled:\(item.id)"
        let tile = SKShapeNode(rectOf: size, cornerRadius: 14)
        tile.fillColor = UIColor(white: 0, alpha: 0.045)
        tile.strokeColor = UIColor(white: 0, alpha: 0.07)
        tile.lineWidth = 1
        tile.position = point
        tile.name = tileName
        parent.addChild(tile)

        let iconDisc = SKShapeNode(circleOfRadius: min(20, size.height * 0.25))
        iconDisc.fillColor = item.iconBg
        iconDisc.strokeColor = .clear
        iconDisc.position = CGPoint(x: -size.width / 2 + 26, y: size.height / 2 - 24)
        tile.addChild(iconDisc)

        addIcon(for: item, to: iconDisc, size: 20)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = item.title
        title.fontSize = 12.5
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -size.width / 2 + 50, y: size.height / 2 - 18)
        fitLabelOrTruncate(title, maxWidth: size.width - 60, minFontSize: 10)
        tile.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = item.subtitle
        subtitle.fontSize = 9.5
        subtitle.fontColor = UIColor(hex: "#475569")
        subtitle.verticalAlignmentMode = .center
        subtitle.horizontalAlignmentMode = .left
        subtitle.position = CGPoint(x: -size.width / 2 + 50, y: size.height / 2 - 36)
        fitLabelOrTruncate(subtitle, maxWidth: size.width - 58, minFontSize: 8)
        tile.addChild(subtitle)

        if let progress = item.progress {
            addProgressMeter(to: tile,
                             item: item,
                             progress: progress,
                             width: size.width - 58,
                             atY: -size.height / 2 + 37,
                             labelY: -size.height / 2 + 47)
        }

        let btnW: CGFloat = size.width - 22
        let btnH: CGFloat = 27
        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        btn.fillColor = item.enabled ? item.buttonColor : UIColor(white: 0, alpha: 0.08)
        btn.strokeColor = .clear
        btn.position = CGPoint(x: 0, y: -size.height / 2 + 18)
        btn.name = tileName
        if !item.enabled {
            btn.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.72, duration: 0.55),
                .fadeAlpha(to: 1.0, duration: 0.55)
            ])))
        }
        tile.addChild(btn)

        let btnL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnL.text = item.buttonText
        btnL.fontSize = 11.5
        btnL.fontColor = item.enabled ? item.buttonTextColor : UIColor(white: 0, alpha: 0.4)
        btnL.verticalAlignmentMode = .center
        btnL.horizontalAlignmentMode = .center
        fitLabel(btnL, maxWidth: btnW - 12, minFontSize: 9)
        btn.addChild(btnL)

        tile.isAccessibilityElement = true
        tile.accessibilityLabel = "\(item.title). \(item.subtitle). \(item.buttonText)"
        tile.accessibilityTraits = item.enabled ? .button : [.button, .notEnabled]
    }

    private func buildFeatureTile(_ item: Item, into parent: SKNode, at point: CGPoint, size: CGSize) {
        let tileName = item.enabled ? "shopBuy:\(item.id)" : "shopDisabled:\(item.id)"
        let tile = SKShapeNode(rectOf: size, cornerRadius: 16)
        tile.fillColor = UIColor(white: 0, alpha: 0.045)
        tile.strokeColor = item.buttonColor.withAlphaComponent(item.enabled ? 0.22 : 0.08)
        tile.lineWidth = 1
        tile.position = point
        tile.name = tileName
        parent.addChild(tile)

        let iconDisc = SKShapeNode(circleOfRadius: 24)
        iconDisc.fillColor = item.iconBg
        iconDisc.strokeColor = .clear
        iconDisc.position = CGPoint(x: -size.width / 2 + 34, y: size.height / 2 - 34)
        tile.addChild(iconDisc)
        addIcon(for: item, to: iconDisc, size: 23)

        let textX = -size.width / 2 + 70
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = item.title
        title.fontSize = 14.5
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: textX, y: size.height / 2 - 25)
        fitLabelOrTruncate(title, maxWidth: size.width - 168, minFontSize: 11)
        tile.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = item.subtitle
        subtitle.fontSize = 10.5
        subtitle.fontColor = UIColor(hex: "#475569")
        subtitle.verticalAlignmentMode = .center
        subtitle.horizontalAlignmentMode = .left
        subtitle.position = CGPoint(x: textX, y: size.height / 2 - 47)
        fitLabelOrTruncate(subtitle, maxWidth: size.width - 168, minFontSize: 8.5)
        tile.addChild(subtitle)

        let btnW: CGFloat = 96
        let btnH: CGFloat = 30
        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        btn.fillColor = item.enabled ? item.buttonColor : UIColor(white: 0, alpha: 0.08)
        btn.strokeColor = .clear
        btn.position = CGPoint(x: size.width / 2 - 18 - btnW / 2, y: -size.height / 2 + 25)
        btn.name = tileName
        if !item.enabled {
            btn.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.72, duration: 0.55),
                .fadeAlpha(to: 1.0, duration: 0.55)
            ])))
        }
        tile.addChild(btn)

        let btnL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnL.text = item.buttonText
        btnL.fontSize = 11.5
        btnL.fontColor = item.enabled ? item.buttonTextColor : UIColor(white: 0, alpha: 0.4)
        btnL.verticalAlignmentMode = .center
        btnL.horizontalAlignmentMode = .center
        fitLabel(btnL, maxWidth: btnW - 12, minFontSize: 8.5)
        btn.addChild(btnL)

        if let progress = item.progress {
            let buttonLeft = btn.position.x - btnW / 2
            let meterW = max(80, buttonLeft - 12 - textX)
            addProgressMeter(to: tile,
                             item: item,
                             progress: progress,
                             width: meterW,
                             atY: -size.height / 2 + 20,
                             labelY: -size.height / 2 + 37,
                             x: textX + meterW / 2)
        }

        tile.isAccessibilityElement = true
        tile.accessibilityLabel = "\(item.title). \(item.subtitle). \(item.buttonText)"
        tile.accessibilityTraits = item.enabled ? .button : [.button, .notEnabled]
    }

    private func addIcon(for item: Item, to parent: SKNode, size: CGFloat) {
        if let emoji = item.emojiIcon {
            let label = SKLabelNode(text: emoji)
            label.fontSize = size
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            parent.addChild(label)
        } else if let symbol = item.symbolIcon {
            let sprite = Icons.sprite(symbol, size: size - 3, weight: .heavy, tint: item.iconTint)
            parent.addChild(sprite)
        }
    }

    private func addProgressMeter(to parent: SKNode,
                                  item: Item,
                                  progress: CGFloat,
                                  width: CGFloat,
                                  atY y: CGFloat,
                                  labelY: CGFloat,
                                  x: CGFloat = 0) {
        let meterH: CGFloat = 6
        let track = SKShapeNode(rectOf: CGSize(width: width, height: meterH), cornerRadius: meterH / 2)
        track.fillColor = UIColor(white: 0, alpha: 0.10)
        track.strokeColor = .clear
        track.position = CGPoint(x: x, y: y)
        parent.addChild(track)

        let fill = SKShapeNode(rectOf: CGSize(width: width, height: meterH), cornerRadius: meterH / 2)
        fill.fillColor = item.buttonColor.withAlphaComponent(item.enabled ? 0.90 : 0.45)
        fill.strokeColor = .clear
        let clamped = max(0.0001, min(1.0, progress))
        fill.xScale = clamped
        fill.position = CGPoint(x: x - width / 2 + width * clamped / 2, y: y)
        if !item.enabled {
            fill.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.7),
                .fadeAlpha(to: 1.0, duration: 0.7)
            ])))
        }
        parent.addChild(fill)

        if let meterText = item.meterText {
            let meterLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            meterLabel.text = meterText
            meterLabel.fontSize = 8.5
            meterLabel.fontColor = UIColor(hex: "#64748B")
            meterLabel.verticalAlignmentMode = .center
            meterLabel.horizontalAlignmentMode = .left
            meterLabel.position = CGPoint(x: x - width / 2, y: labelY)
            fitLabelOrTruncate(meterLabel, maxWidth: width, minFontSize: 7)
            parent.addChild(meterLabel)
        }
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

    private func makeCoin(diameter: CGFloat) -> SKShapeNode {
        let coin = SKShapeNode(circleOfRadius: diameter / 2)
        coin.fillColor = UIColor(hex: "#FFD700")
        coin.strokeColor = UIColor(hex: "#D97706")
        coin.lineWidth = 1
        let dollar = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        dollar.text = "$"
        dollar.fontSize = diameter * 0.6
        dollar.fontColor = UIColor(hex: "#7C2D12")
        dollar.verticalAlignmentMode = .center
        dollar.horizontalAlignmentMode = .center
        coin.addChild(dollar)
        return coin
    }

    /// Update the wallet number after a purchase without rebuilding the whole card.
    func setWallet(_ value: Int) {
        walletLabel.text = "\(value)"
        walletLabel.run(.sequence([
            .scale(to: 1.2, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }

    /// Hit-test a tap and route to the right callback.
    func handleTap(at scenePoint: CGPoint) -> Bool {
        let local = self.convert(scenePoint, from: self.parent ?? self)
        var node: SKNode? = atPoint(local)
        while let current = node {
            if let name = current.name, name.hasPrefix("shopTab:") {
                let rawValue = String(name.dropFirst("shopTab:".count))
                if let tab = Item.Tab(rawValue: rawValue), availableTabs.contains(tab) {
                    selectedTab = tab
                    renderTabs()
                    renderContent()
                    bounce(current)
                }
                return true
            }
            if current.name == "shopClose" || current.name == "shopScrim" {
                onClose?()
                return true
            }
            if let name = current.name, name.hasPrefix("shopBuy:") {
                let id = String(name.dropFirst("shopBuy:".count))
                bounce(current)
                onBuy?(id)
                return true
            }
            if let name = current.name, name.hasPrefix("shopDisabled:") {
                bounce(current)
                return true
            }
            node = current.parent
        }
        return true
    }

    func dismiss(_ completion: (() -> Void)? = nil) {
        run(.sequence([
            .group([.scale(to: 0.4, duration: 0.16),
                    .fadeOut(withDuration: 0.16)]),
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
