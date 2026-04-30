import SpriteKit
import UIKit

/// In-game shop. Glass card with a wallet header, a list of products, and a
/// close button. Each product row reports back via `onBuy(itemId)`.
final class ShopCard: SKNode {

    struct Item {
        let id: String
        let emojiIcon: String?       // either emoji…
        let symbolIcon: String?      // …or SF Symbol name
        let iconBg: UIColor
        let iconTint: UIColor
        let title: String
        let subtitle: String
        let buttonText: String
        let buttonColor: UIColor
        let buttonTextColor: UIColor
        let enabled: Bool
    }

    var onBuy: ((String) -> Void)?
    var onClose: (() -> Void)?
    private var walletLabel: SKLabelNode!
    private let cardSize: CGSize

    init(items: [Item], walletCash: Int, sceneSize: CGSize) {
        let h = CGFloat(60 + 84 * items.count + 70)
        cardSize = CGSize(width: min(sceneSize.width - 32, 340),
                          height: min(sceneSize.height - 100, h))
        super.init()
        zPosition = 1500
        build(items: items, walletCash: walletCash, sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func build(items: [Item], walletCash: Int, sceneSize: CGSize) {
        // Scrim
        let scrim = SKShapeNode(rectOf: sceneSize)
        scrim.fillColor = UIColor(white: 0, alpha: 0.55)
        scrim.strokeColor = .clear
        scrim.zPosition = 0
        scrim.name = "shopScrim"
        scrim.alpha = 0
        addChild(scrim)
        scrim.run(.fadeAlpha(to: 1.0, duration: 0.18))

        // Card
        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 24)
        card.fillColor = UIColor(white: 1, alpha: 0.97)
        card.strokeColor = UIColor.white.withAlphaComponent(0.6)
        card.lineWidth = 1
        card.zPosition = 1
        card.alpha = 0
        card.setScale(0.7)
        addChild(card)
        card.run(.group([.fadeIn(withDuration: 0.18),
                         .scale(to: 1.0, duration: 0.22)]))

        // Header — title + wallet
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "Shop"
        title.fontSize = 24
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -cardSize.width / 2 + 24, y: cardSize.height / 2 - 30)
        card.addChild(title)

        // Wallet pill (top-right of header)
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

        // Divider under header
        let divider = SKShapeNode(rectOf: CGSize(width: cardSize.width - 40, height: 1))
        divider.fillColor = UIColor(white: 0, alpha: 0.08)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: cardSize.height / 2 - 56)
        card.addChild(divider)

        // Item rows
        var y = cardSize.height / 2 - 56 - 50
        for item in items {
            buildRow(item, into: card, atY: y)
            y -= 84
        }

        // Close button
        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = "Close"
        close.fontSize = 14
        close.fontColor = UIColor(hex: "#475569")
        close.verticalAlignmentMode = .center
        close.horizontalAlignmentMode = .center
        close.position = CGPoint(x: 0, y: -cardSize.height / 2 + 24)
        close.name = "shopClose"
        card.addChild(close)
    }

    private func buildRow(_ item: Item, into parent: SKNode, atY y: CGFloat) {
        let rowW = cardSize.width - 32
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: 72), cornerRadius: 16)
        row.fillColor = UIColor(white: 0, alpha: 0.04)
        row.strokeColor = UIColor(white: 0, alpha: 0.06)
        row.lineWidth = 1
        row.position = CGPoint(x: 0, y: y)
        parent.addChild(row)

        // Icon disc (left)
        let iconDisc = SKShapeNode(circleOfRadius: 22)
        iconDisc.fillColor = item.iconBg
        iconDisc.strokeColor = .clear
        iconDisc.position = CGPoint(x: -rowW / 2 + 36, y: 0)
        row.addChild(iconDisc)

        if let emoji = item.emojiIcon {
            let l = SKLabelNode(text: emoji)
            l.fontSize = 22
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            iconDisc.addChild(l)
        } else if let sym = item.symbolIcon {
            let s = Icons.sprite(sym, size: 18, weight: .heavy, tint: item.iconTint)
            iconDisc.addChild(s)
        }

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = item.title
        title.fontSize = 15
        title.fontColor = UIColor(hex: "#0F172A")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -rowW / 2 + 70, y: 9)
        row.addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = item.subtitle
        subtitle.fontSize = 12
        subtitle.fontColor = UIColor(hex: "#475569")
        subtitle.verticalAlignmentMode = .center
        subtitle.horizontalAlignmentMode = .left
        subtitle.position = CGPoint(x: -rowW / 2 + 70, y: -9)
        row.addChild(subtitle)

        // Right-side button
        let btnW: CGFloat = 72
        let btnH: CGFloat = 34
        let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        btn.fillColor = item.enabled ? item.buttonColor : UIColor(white: 0, alpha: 0.08)
        btn.strokeColor = .clear
        btn.position = CGPoint(x: rowW / 2 - 8 - btnW / 2, y: 0)
        btn.name = item.enabled ? "shopBuy:\(item.id)" : "shopDisabled:\(item.id)"
        row.addChild(btn)

        let btnL = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnL.text = item.buttonText
        btnL.fontSize = 13
        btnL.fontColor = item.enabled ? item.buttonTextColor : UIColor(white: 0, alpha: 0.4)
        btnL.verticalAlignmentMode = .center
        btnL.horizontalAlignmentMode = .center
        btn.addChild(btnL)
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
        var n: SKNode? = atPoint(local)
        while let node = n {
            if node.name == "shopClose" || node.name == "shopScrim" {
                onClose?()
                return true
            }
            if let name = node.name, name.hasPrefix("shopBuy:") {
                let id = String(name.dropFirst("shopBuy:".count))
                bounce(node)
                onBuy?(id)
                return true
            }
            if let name = node.name, name.hasPrefix("shopDisabled:") {
                bounce(node)  // ignore — disabled
                return true
            }
            n = node.parent
        }
        return true   // swallow taps inside the card
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
