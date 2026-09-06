import SpriteKit

/// A single renderer for every board shape/world; a Cell's metadata never
/// determines matching, gravity, or special mechanics here.
enum BoardRenderer {
    static func specialAsset(_ special: Special) -> String {
        switch special {
        case .stripedRow: return "special_striped_horizontal"
        case .stripedCol: return "special_striped_vertical"
        case .wrapped: return "special_wrapped"
        case .colorBomb: return "special_color_bomb"
        case .fish: return "special_fish"
        case .rocket: return "special_rocket"
        case .lineBlast, .bomb: return "special_line_blast"
        case .ufo: return "special_ufo"
        }
    }
    static func blockerAsset(_ blocker: Blocker) -> String {
        let layer = String(format: "%02d", min(blocker.type == .cream ? 5 : 3, max(1, blocker.hits)))
        switch blocker.type {
        case .ice, .honey, .stone, .cream: return "blocker_\(blocker.type.rawValue)_\(layer)"
        case .jelly: return "blocker_jelly_\(String(format: "%02d", min(2, max(1, blocker.hits))))"
        case .colorLock: return "blocker_lock"
        case .magicFrost: return "blocker_magic_frost"
        case .solidX: return "blocker_stone_03"
        case .syrup: return "blocker_honey_01"
        case .chest: return "ui_shop"
        default: return "blocker_\(blocker.type.rawValue)"
        }
    }
    static func makeTile(cell: Cell, size: CGFloat, accessibilityLabel: String) -> SKNode {
        let container = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.20)
        body.name = "body"
        body.fillColor = .clear
        body.strokeColor = Persistence.highContrast ? UIColor.white : .clear
        body.lineWidth = Persistence.highContrast ? 2 : 0.6
        body.addChild(GameplayHUDArt.tile(size: size))
        container.addChild(body)
        if let blocker = cell.blocker, blocker.type == .jelly {
            addBlocker(blocker, to: container, size: size, underPiece: true)
        }
        if let piece = cell.piece {
            let art: SKSpriteNode
            if let special = piece.special, GameArt.texture(specialAsset(special)) != nil {
                art = GameArt.sprite(specialAsset(special), fitting: CGSize(width: size * 1.04, height: size * 1.04))
                // Base color remains legible for color-bomb combination rules.
                if special != .colorBomb {
                    let colorFruit = SKSpriteNode(texture: GameArt.fruit(piece.color))
                    colorFruit.size = CGSize(width: size * 0.32, height: size * 0.32)
                    colorFruit.position = CGPoint(x: size * 0.30, y: -size * 0.28)
                    colorFruit.zPosition = 6
                    container.addChild(colorFruit)
                }
            } else {
                art = SKSpriteNode(texture: GameArt.fruit(piece.color))
                art.size = CGSize(width: size * 1.04, height: size * 1.04)
            }
            art.name = "emoji" // Existing particle/swap adapters retain this hook.
            art.zPosition = 2
            container.addChild(art)
            if piece.kind == .key {
                let key = GameArt.sprite("blocker_key", fitting: CGSize(width: size * 0.56, height: size * 0.56))
                key.zPosition = 8
                container.addChild(key)
            }
            if piece.kind == .ingredient {
                let rim = SKShapeNode(rectOf: CGSize(width: size * 0.84, height: size * 0.84), cornerRadius: size * 0.2)
                rim.strokeColor = UIColor(hex: "#7BFFA0")
                rim.fillColor = .clear
                rim.lineWidth = 2
                rim.zPosition = 3
                container.addChild(rim)
            }
            if Persistence.candyLabels || Persistence.colorBlindPatterns {
                let label = GameSurface.label(String(piece.color.rawValue.prefix(1)).uppercased(), size: max(10, size * 0.2), color: .white)
                label.position = CGPoint(x: -size * 0.3, y: -size * 0.3)
                label.zPosition = 10
                container.addChild(label)
            }
        }
        if let blocker = cell.blocker, blocker.type != .jelly {
            addBlocker(blocker, to: container, size: size, underPiece: false)
        }
        container.isAccessibilityElement = true
        container.accessibilityLabel = accessibilityLabel
        container.accessibilityTraits = .button
        container.userData = NSMutableDictionary(dictionary: ["color": cell.color])
        return container
    }

    static func addBlocker(_ blocker: Blocker, to container: SKNode, size: CGFloat, underPiece: Bool) {
        let artName = blockerAsset(blocker)
        if GameArt.texture(artName) != nil {
            let art = GameArt.sprite(artName, fitting: CGSize(width: size * 0.99, height: size * 0.99))
            art.zPosition = underPiece ? 1 : 7
            if blocker.type.rules.canContainPiece { art.alpha = underPiece ? 0.75 : 0.72 }
            container.addChild(art)
        } else if [.lock, .colorLock, .cage, .crate, .vine].contains(blocker.type) {
            let wooden = blocker.type == .crate || blocker.type == .vine
            let frame = SKNode()
            frame.zPosition = underPiece ? 1 : 7
            let edge = size * 0.39
            if wooden {
                let face = GameSurface.panel(size: CGSize(width: size * 0.88, height: size * 0.88),
                    top: UIColor(hex: "#C48850"), bottom: UIColor(hex: "#794020"), radius: size * 0.1,
                    rim: UIColor(hex: "#E4B57C"))
                frame.addChild(face)
            }
            for rotation in [CGFloat.pi / 4, -CGFloat.pi / 4] {
                let band = GameSurface.panel(size: CGSize(width: size * 1.04, height: size * 0.15),
                    top: UIColor(hex: wooden ? "#EDC594" : "#E1EDF5"),
                    bottom: UIColor(hex: wooden ? "#9A6439" : "#697C96"),
                    radius: size * 0.06, rim: UIColor(hex: wooden ? "#684127" : "#354960"))
                band.zRotation = rotation
                frame.addChild(band)
            }
            for x in [-edge, edge] {
                for y in [-edge, edge] {
                    let screw = SKShapeNode(circleOfRadius: size * 0.065)
                    screw.fillColor = UIColor(hex: "#DBE6EE")
                    screw.strokeColor = UIColor(hex: "#5E6C81")
                    screw.lineWidth = size * 0.025
                    screw.position = CGPoint(x: x * 0.88, y: y * 0.88)
                    frame.addChild(screw)
                }
            }
            let center = SKShapeNode(circleOfRadius: size * 0.085)
            center.fillColor = UIColor(hex: "#B7C6D6")
            center.strokeColor = UIColor(hex: "#526377")
            center.lineWidth = size * 0.025
            frame.addChild(center)
            container.addChild(frame)
        } else {
            // Existing mechanics remain readable if an optional skin is absent.
            // Layer count, silhouette and cracks always reflect real hit points.
            let color: UIColor
            switch blocker.type {
            case .ice, .magicFrost, .bubble: color = UIColor(hex: "#8CD9FF")
            case .jelly: color = UIColor(hex: "#ED83C4")
            case .honey, .syrup: color = UIColor(hex: "#F6AF25")
            case .chocolate: color = UIColor(hex: "#763B23")
            case .cream: color = UIColor(hex: "#FFF1DA")
            default: color = UIColor(hex: "#9FA7BA")
            }
            let shell = SKShapeNode(rectOf: CGSize(width: size * 0.88, height: size * 0.88), cornerRadius: size * 0.12)
            shell.fillColor = color.withAlphaComponent(blocker.type.rules.canContainPiece ? 0.28 : 1)
            shell.strokeColor = color.lighter(by: 0.25)
            shell.lineWidth = 2
            shell.zPosition = underPiece ? 1 : 7
            container.addChild(shell)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -size * 0.34, y: size * 0.25))
            path.addLine(to: CGPoint(x: -size * 0.1, y: size * 0.1))
            path.addLine(to: CGPoint(x: -size * 0.17, y: -size * 0.03))
            path.addLine(to: CGPoint(x: size * 0.22, y: -size * 0.3))
            let crack = SKShapeNode(path: path)
            crack.strokeColor = color.darker(by: 0.35)
            crack.lineWidth = blocker.hits == 1 ? 2.5 : 1
            shell.addChild(crack)
        }
        if blocker.hits > 1 || blocker.type == .countdown {
            let value = GameSurface.label("\(blocker.countdown ?? blocker.hits)", size: max(10, size * 0.22), color: .white)
            let badge = SKShapeNode(circleOfRadius: size * 0.15)
            badge.fillColor = UIColor(hex: "#172C51")
            badge.strokeColor = .white
            badge.position = CGPoint(x: size * 0.28, y: size * 0.28)
            badge.zPosition = 10
            badge.addChild(value)
            container.addChild(badge)
        }
    }
}
