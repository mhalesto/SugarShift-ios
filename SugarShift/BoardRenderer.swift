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
    static func makeTile(cell: Cell, size: CGFloat, accessibilityLabel: String, theme: WorldThemeDefinition? = nil) -> SKNode {
        let container = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.20)
        body.name = "body"
        body.fillColor = .clear
        body.strokeColor = Persistence.highContrast ? UIColor.white : .clear
        body.lineWidth = Persistence.highContrast ? 2 : 0.6
        let background = GameplayHUDArt.tile(size: size)
        background.name = "tileBackground"
        background.alpha = CGFloat(1 - Persistence.boardTransparency)
        body.addChild(background)
        container.addChild(body)
        if let blocker = cell.blocker, blocker.type == .jelly {
            addBlocker(blocker, to: container, size: size, underPiece: true, theme: theme)
        }
        if let piece = cell.piece {
            let art: SKSpriteNode
            if let special = piece.special, GameArt.texture(specialAsset(special)) != nil {
                let asset = theme?.id == "cloud" && special == .wrapped ? "combo_balloon" : specialAsset(special)
                art = GameArt.boardSprite(asset, fitting: CGSize(width: size * 0.94, height: size * 0.94))
                // Base color remains legible for color-bomb combination rules.
                if special != .colorBomb {
                    let colorFruit = GameArt.boardSprite(theme?.pieceAsset(piece.color) ?? "fruit_\(piece.color.rawValue)", fitting: CGSize(width: size * 0.25, height: size * 0.25))
                    colorFruit.position = CGPoint(x: size * 0.30, y: -size * 0.28)
                    colorFruit.zPosition = 6
                    container.addChild(colorFruit)
                }
            } else {
                art = GameArt.boardSprite(theme?.pieceAsset(piece.color) ?? "fruit_\(piece.color.rawValue)", fitting: CGSize(width: size * 0.92, height: size * 0.94))
            }
            art.name = "emoji" // Existing particle/swap adapters retain this hook.
            art.zPosition = 2
            container.addChild(art)
            if piece.kind == .key {
                let key = GameArt.boardSprite("objective_key", fitting: CGSize(width: size * 0.78, height: size * 0.78))
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
            addBlocker(blocker, to: container, size: size, underPiece: false, theme: theme)
        }
        container.isAccessibilityElement = true
        container.accessibilityLabel = accessibilityLabel
        container.accessibilityTraits = .button
        container.userData = NSMutableDictionary(dictionary: ["color": cell.color])
        return container
    }

    static func addBlocker(_ blocker: Blocker, to container: SKNode, size: CGFloat, underPiece: Bool, theme: WorldThemeDefinition? = nil) {
        let artName = theme?.blockerAsset(blocker) ?? blockerAsset(blocker)
        if GameArt.texture(artName) != nil {
            let art = GameArt.boardSprite(artName, fitting: CGSize(width: size * 0.97, height: size * 0.97))
            art.name = "blockerArt"
            art.zPosition = underPiece ? 1 : 7
            if [.ice, .magicFrost, .bubble].contains(blocker.type) {
                art.alpha = 0.72
                // Preserve bright frozen edges while the real fruit remains
                // visible through the center of the separately anchored layer.
                let rim = SKShapeNode(rectOf: CGSize(width: size * 0.94, height: size * 0.94), cornerRadius: size * 0.16)
                rim.fillColor = .clear
                rim.strokeColor = UIColor(hex: "#C5F7FF").withAlphaComponent(0.9)
                rim.lineWidth = size * 0.027
                rim.glowWidth = 0.5
                rim.zPosition = 8
                container.addChild(rim)
            } else if blocker.type == .jelly { art.alpha = 0.65 }
            container.addChild(art)
            if blocker.hits > 1, ![.ice, .jelly, .honey, .cream].contains(blocker.type) {
                // Reusable fracture overlay exposes the actual damage state of
                // thematic stone/wood skins without inventing another mechanic.
                art.color = UIColor.white
                art.colorBlendFactor = blocker.hits == 2 ? 0.08 : 0
            }
        } else if [.lock, .colorLock, .cage, .crate, .vine].contains(blocker.type) {
            let wooden = blocker.type == .crate || blocker.type == .vine
            let frame = SKNode()
            frame.name = "blockerArt"
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
            shell.name = "blockerArt"
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
        BlockerDamageArtwork.apply(to: container, blocker: blocker, size: size, theme: theme)
        if (Persistence.highContrast && blocker.hits > 1) || blocker.type == .countdown {
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
