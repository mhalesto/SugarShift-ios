import SpriteKit

/// Presentation only. The board engine never imports a world or an art asset.
struct WorldThemeDefinition {
    let id: String
    let displayName: String
    let levels: ClosedRange<Int>
    let accent: String
    let secondary: String
    let ambience: AmbientStyle
    let comboTitle: String
    var backgroundAsset: String { "world_\(id)_background" }
    var glowColor: UIColor { UIColor(hex: accent) }
    var boardRimColor: UIColor {
        UIColor(hex: id == "ice" ? "#65DFFF" : id == "galaxy" ? "#C48BFF" : id == "volcano" ? "#FF993F" : "#FFD18A")
    }
    var cardPalette: WorldCardPalette {
        switch id {
        case "ice": return .init(top: "#F0FDFF", middle: "#D2F3FF", bottom: "#B1E7FF", ink: "#152274", trim: "#63D9FF", shadow: "#4CA9D7")
        case "coral": return .init(top: "#E4FBFF", middle: "#BAF3FF", bottom: "#8AE1F8", ink: "#241052", trim: "#03C7F5", shadow: "#32AFD6")
        case "galaxy": return .init(top: "#5E2BB6", middle: "#382070", bottom: "#613BC4", ink: "#FFF5FF", trim: "#862EFF", shadow: "#26114D")
        case "sakura", "cloud": return .init(top: "#FFF3F7", middle: "#FBE0EC", bottom: "#F3C5DE", ink: "#340B4F", trim: "#FF56C5", shadow: "#C47B9B")
        case "honey", "golden", "sahara", "firefly": return .init(top: "#FFF4DF", middle: "#FFE6C2", bottom: "#FBD5AC", ink: "#4D172B", trim: "#FFB400", shadow: "#C18955")
        case "volcano": return .init(top: "#FFF3E5", middle: "#FFE4D2", bottom: "#F8D3BA", ink: "#4D0C23", trim: "#FF6900", shadow: "#C97748")
        default: return .init(top: "#FFF5E9", middle: "#FFE1D5", bottom: "#F9D2D0", ink: "#46113F", trim: "#FF4D99", shadow: "#BD796C")
        }
    }
    var comboStyle: WorldComboStyle? {
        switch id {
        case "volcano": return .eruption
        case "coral": return .whaleWave
        case "ice": return .frost
        case "honey": return .honey
        case "cloud": return .rainbow
        case "golden": return .amber
        case "firefly": return .firefly
        case "sahara": return .sandstorm
        case "galaxy": return .cosmic
        case "sakura": return .petal
        default: return .sugar
        }
    }
    var comboHeroAsset: String? {
        switch comboStyle {
        case .eruption: return "combo_volcano_core"
        case .whaleWave: return "combo_whale"
        case .frost: return "special_striped_vertical"
        case .honey: return "combo_honey_jar"
        case .rainbow: return "combo_balloon"
        case .amber: return "objective_amber"
        case .firefly: return "combo_firefly_jar"
        case .sandstorm: return "combo_sandstorm"
        case .cosmic: return "combo_planet"
        case .petal: return "combo_blossom"
        case .sugar: return "special_color_bomb"
        case nil: return nil
        }
    }
    enum AmbientStyle { case sparkle, snow, honey, ember, bubble, cloud, sand, firefly, cosmic, petal }

    func pieceAsset(_ color: PieceColor) -> String {
        let overrides: [PieceColor: String]
        switch id {
        case "honey": overrides = [.heart: "objective_donut", .grape: "combo_honey_jar"]
        case "coral": overrides = [.heart: "objective_pearl", .grape: "objective_shell", .leaf: "objective_starfish"]
        case "cloud": overrides = [.grape: "objective_rainbow", .heart: "objective_star"]
        case "golden": overrides = [.heart: "combo_honey_jar", .grape: "objective_amber"]
        case "firefly": overrides = [.heart: "combo_firefly_jar", .grape: "combo_blossom"]
        case "sahara": overrides = [.heart: "objective_scarab", .grape: "objective_urn"]
        case "sakura": overrides = [.heart: "combo_blossom", .grape: "objective_lantern"]
        default: overrides = [:]
        }
        return overrides[color] ?? "fruit_\(color.rawValue)"
    }

    func blockerAsset(_ blocker: Blocker) -> String {
        switch (id, blocker.type) {
        case ("cloud", .cream): return "blocker_cloud"
        case ("volcano", .stone), ("volcano", .crate): return "blocker_magma"
        case ("coral", .vine), ("coral", .cage): return "blocker_seaweed"
        case ("coral", .crate): return "blocker_barrel"
        case ("firefly", .vine), ("firefly", .crate): return "blocker_vine_crate"
        case ("sahara", .stone), ("golden", .stone): return "blocker_sandstone"
        case ("sahara", .crate), ("golden", .crate): return "blocker_tablet"
        case ("galaxy", .stone): return "blocker_asteroid"
        case ("sakura", .stone): return "blocker_pink_crystal"
        case ("sakura", .cage), ("sakura", .vine): return "blocker_rope"
        default: return BoardRenderer.blockerAsset(blocker)
        }
    }

    func objectiveAsset(_ objective: LevelObjective) -> String {
        switch objective {
        case .collectPieces(let color, _): return pieceAsset(color)
        case .destroySpecificBlocker(let type, _): return blockerAsset(Blocker(type: type, hits: 1))
        case .collectKeys: return "objective_key"
        default: return objective.artName
        }
    }
}

struct WorldCardPalette {
    let top: String
    let middle: String
    let bottom: String
    let ink: String
    let trim: String
    let shadow: String
}

enum WorldThemes {
    static let all: [WorldThemeDefinition] = [
        .init(id: "candy", displayName: String(localized: "Candy Valley"), levels: 1...15, accent: "#FFD995", secondary: "#F86EB0", ambience: .sparkle, comboTitle: String(localized: "Sugar Rush!")),
        .init(id: "ice", displayName: String(localized: "Ice Age"), levels: 16...30, accent: "#9EEDFF", secondary: "#618DEA", ambience: .snow, comboTitle: String(localized: "Frost Break!")),
        .init(id: "honey", displayName: String(localized: "Honey Haven"), levels: 31...45, accent: "#FFD15B", secondary: "#E88B28", ambience: .honey, comboTitle: String(localized: "Golden Rush!")),
        .init(id: "volcano", displayName: String(localized: "Volcano Valley"), levels: 46...60, accent: "#FF9B38", secondary: "#D33739", ambience: .ember, comboTitle: String(localized: "Volcanic Combo!")),
        .init(id: "coral", displayName: String(localized: "Coral Reef"), levels: 61...75, accent: "#72F0F9", secondary: "#2876DF", ambience: .bubble, comboTitle: String(localized: "Whale Combo!")),
        .init(id: "cloud", displayName: String(localized: "Cloud Kingdom"), levels: 76...90, accent: "#FFD5F6", secondary: "#77C8EF", ambience: .cloud, comboTitle: String(localized: "Rainbow Rush!")),
        .init(id: "golden", displayName: String(localized: "Golden Desert"), levels: 91...110, accent: "#FDDD88", secondary: "#B87425", ambience: .sand, comboTitle: String(localized: "Amber Glow!")),
        .init(id: "firefly", displayName: String(localized: "Firefly Forest"), levels: 111...130, accent: "#EDFF8E", secondary: "#203D81", ambience: .firefly, comboTitle: String(localized: "Firefly Burst!")),
        .init(id: "sahara", displayName: String(localized: "Sahara Sands"), levels: 131...150, accent: "#FFD88C", secondary: "#D88139", ambience: .sand, comboTitle: String(localized: "Sandstorm!")),
        .init(id: "galaxy", displayName: String(localized: "Galaxy Getaway"), levels: 151...175, accent: "#D9AAFF", secondary: "#6237CA", ambience: .cosmic, comboTitle: String(localized: "Cosmic Blast!")),
        .init(id: "sakura", displayName: String(localized: "Sakura Sky"), levels: 176...200, accent: "#FFB4DD", secondary: "#573F9B", ambience: .petal, comboTitle: String(localized: "Petal Storm!"))
    ]
    static func theme(for level: Int) -> WorldThemeDefinition {
        all.first { $0.levels.contains(level) } ?? all[0]
    }
}

enum GameArt {
    private static var cache: [String: SKTexture] = [:]
    private static var boardTextures: [String: SKTexture] = [:]
    static func texture(_ name: String) -> SKTexture? {
        if let texture = cache[name] { return texture }
        guard let image = UIImage(named: name) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }
    static func fruit(_ color: PieceColor) -> SKTexture {
        texture("fruit_\(color.rawValue)") ?? Theme.gemTexture(forColor: color.legacyToken)
    }
    static func sprite(_ name: String, fitting size: CGSize) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(name))
        if let texture = node.texture {
            let source = texture.size()
            let ratio = min(size.width / max(1, source.width), size.height / max(1, source.height))
            node.size = CGSize(width: source.width * ratio, height: source.height * ratio)
        } else { node.size = size }
        return node
    }
    /// Optical sizing for board art only. Export gutters must not make a fruit
    /// look smaller than its neighbors. Shared HUD/footer textures are untouched.
    static func boardSprite(_ name: String, fitting size: CGSize) -> SKSpriteNode {
        let texture: SKTexture?
        if let cached = boardTextures[name] { texture = cached }
        else if let source = UIImage(named: name)?.cgImage {
            let width = source.width, height = source.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            pixels.withUnsafeMutableBytes { bytes in
                let cg = CGContext(data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
                cg.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            var minX = width, minY = height, maxX = 0, maxY = 0
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            let bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
                .insetBy(dx: -2, dy: -2).intersection(CGRect(x: 0, y: 0, width: width, height: height))
            if let cropped = source.cropping(to: bounds) {
                let trimmed = SKTexture(cgImage: cropped)
                trimmed.filteringMode = .linear
                boardTextures[name] = trimmed
                texture = trimmed
            } else { texture = self.texture(name) }
        } else { texture = self.texture(name) }
        let node = SKSpriteNode(texture: texture)
        if let texture {
            let source = texture.size()
            let scale = min(size.width / max(1, source.width), size.height / max(1, source.height))
            node.size = CGSize(width: source.width * scale, height: source.height * scale)
        }
        return node
    }
    static func preload() {
        let names = PieceColor.allCases.map { "fruit_\($0.rawValue)" } + ["sugar_shift_logo", "ui_coin", "world_candy_background"]
        SKTexture.preload(names.compactMap { texture($0) }) {}
    }
    static func preload(world: WorldThemeDefinition) {
        SKTexture.preload(([world.backgroundAsset] + [world.comboHeroAsset].compactMap { $0 })
            .compactMap { texture($0) }) {}
    }
}

/// Cached, resolution-independent UI surfaces. Values and labels stay live.
enum GameSurface {
    private static var cache: [String: SKTexture] = [:]
    static func panel(size: CGSize, top: UIColor, bottom: UIColor, radius: CGFloat, rim: UIColor = .white) -> SKSpriteNode {
        let key = "\(size.width):\(size.height):\(top):\(bottom):\(radius):\(rim)"
        let texture: SKTexture
        if let existing = cache[key] { texture = existing }
        else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { context in
                let cg = context.cgContext
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                cg.saveGState()
                path.addClip()
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
                let gleam = UIBezierPath(roundedRect: CGRect(x: 5, y: 4, width: size.width - 10, height: size.height * 0.36), cornerRadius: radius)
                UIColor.white.withAlphaComponent(0.14).setFill()
                gleam.fill()
                cg.restoreGState()
                rim.withAlphaComponent(0.8).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            texture = SKTexture(image: image)
            cache[key] = texture
        }
        let node = SKSpriteNode(texture: texture, size: size)
        let shadow = SKShapeNode(rectOf: CGSize(width: max(1, size.width - 5), height: max(1, size.height - 3)), cornerRadius: radius)
        shadow.fillColor = UIColor(hex: "#102D4B").withAlphaComponent(0.32)
        shadow.strokeColor = .clear
        shadow.position.y = -3
        shadow.zPosition = -1
        node.addChild(shadow)
        return node
    }
    static func label(_ text: String = "", size: CGFloat, color: UIColor = UIColor(hex: "#573348")) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }
}

extension GameScene {
    var worldTheme: WorldThemeDefinition { WorldThemes.theme(for: levelNumber) }
    func buildWorldBackdrop() {
        GameArt.preload(world: worldTheme)
        childNode(withName: "chapterBackdrop")?.removeFromParent()
        let root = SKNode()
        root.name = "chapterBackdrop"
        root.zPosition = -2500
        let texture = GameArt.texture(worldTheme.backgroundAsset) ?? GameArt.texture("world_candy_background")
        let art = SKSpriteNode(texture: texture)
        if let texture {
            let factor = max(size.width / texture.size().width, size.height / texture.size().height)
            art.size = CGSize(width: texture.size().width * factor, height: texture.size().height * factor)
        }
        root.addChild(art)
        if !Persistence.reduceMotion && !UIAccessibility.isReduceMotionEnabled {
            let emitter = SKEmitterNode()
            let rising = worldTheme.ambience == .bubble || worldTheme.ambience == .ember
            emitter.particleTexture = WorldEffectTextures.ambientTexture(worldTheme.ambience)
            emitter.particleBirthRate = 2.5
            emitter.numParticlesToEmit = 0
            emitter.particleLifetime = 10
            emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
            emitter.position.y = rising ? -size.height / 2 - 12 : size.height / 2 + 12
            emitter.emissionAngle = rising ? .pi / 2 : -.pi / 2
            emitter.emissionAngleRange = 0.4
            emitter.particleSpeed = 30
            emitter.particleSpeedRange = 14
            emitter.particleScale = worldTheme.ambience == .cloud ? 0.75 : worldTheme.ambience == .bubble ? 0.30 : worldTheme.ambience == .firefly ? 0.24 : 0.16
            emitter.particleScaleRange = 0.05
            emitter.particleColor = worldTheme.glowColor
            emitter.particleColorBlendFactor = 0.15
            emitter.particleRotationRange = worldTheme.ambience == .petal ? .pi : 0
            emitter.particleRotationSpeed = worldTheme.ambience == .petal ? 0.45 : 0
            emitter.particleAlpha = 0.35
            emitter.particleAlphaSpeed = -0.025
            emitter.particleSize = CGSize(width: 36, height: 36)
            root.addChild(emitter)
        }
        addChild(root)
    }
}
