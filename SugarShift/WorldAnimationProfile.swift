import Foundation

enum AnimationMaterial: String, CaseIterable {
    case fruit, firefly, vine, flower, ice, honey, donut, lava, water, seaweed
    case cloud, star, rainbow, sandstone, amber, scarab, pottery, cosmic, crystal, lantern, wood, chocolate
    case stone, metal, jelly, cream
}

/// Optics/material selection is deliberately outside the mechanical event stream.
struct WorldAnimationProfile {
    let material: AnimationMaterial
    let tint: String
    let secondary: String
    let gravity: Double
    let hitDuration: Double
    let destructionDuration: Double

    static func material(worldID: String, asset: String, blocker: BlockerType? = nil) -> AnimationMaterial {
        if worldID == "golden", asset.contains("honey_jar") { return .amber }
        if worldID == "coral", blocker == .stone { return .stone }
        let mappings: [(String, AnimationMaterial)] = [
            ("firefly", .firefly), ("vine", .vine), ("rope", .vine), ("blossom", .flower),
            ("ice", .ice), ("frost", .ice), ("honey", .honey), ("donut", .donut),
            ("magma", .lava), ("volcano", .lava), ("seaweed", .seaweed),
            ("pearl", .water), ("shell", .water), ("starfish", .water), ("bubble", .water),
            ("cloud", .cloud), ("rainbow", .rainbow), ("objective_star", .star),
            ("sandstone", .sandstone), ("tablet", .sandstone), ("amber", .amber),
            ("scarab", .scarab), ("urn", .pottery), ("asteroid", .cosmic), ("planet", .cosmic),
            ("crystal", .crystal), ("lantern", .lantern), ("chocolate", .chocolate),
            ("crate", .wood), ("barrel", .wood), ("stone", .stone), ("jelly", .jelly),
            ("cream", .cream), ("lock", .metal), ("cage", .metal), ("key", .metal)]
        return mappings.first { asset.contains($0.0) }?.1
            ?? (blocker == .chest ? .wood : blocker == nil ? .fruit : .stone)
    }

    static func profile(for material: AnimationMaterial, worldID: String = "candy") -> WorldAnimationProfile {
        let colors: (String, String, Double)
        switch material {
        case .firefly: colors = ("#FFE75B", "#FFFFCC", -35)
        case .vine, .seaweed: colors = ("#94EA67", "#D9FFA2", material == .seaweed ? -24 : 150)
        case .flower: colors = ("#FF9BD9", "#FFF5AE", -28)
        case .ice: colors = ("#8CEFFF", "#F4FFFF", 135)
        case .honey, .donut: colors = ("#FFCA48", "#FFF2A5", 130)
        case .lava: colors = ("#FF742D", "#FFE884", 180)
        case .water: colors = ("#73EBFF", "#EAFFFF", -35)
        case .cloud: colors = ("#E0EFFF", "#FFCEEB", -12)
        case .star, .rainbow: colors = ("#FFEE81", "#B9EFFF", -30)
        case .sandstone, .pottery: colors = ("#EABD7E", "#FFF0C1", 190)
        case .amber: colors = ("#FFCE43", "#FFFFAF", 115)
        case .scarab: colors = ("#6DDCFF", "#FFE266", -45)
        case .cosmic: colors = ("#CC8AFF", "#C4F5FF", -8)
        case .crystal: colors = ("#FFB0ED", "#FFF4FF", 90)
        case .lantern: colors = ("#FFBB76", "#FFF2BE", -48)
        case .wood: colors = ("#D59A67", "#FFDBAA", 190)
        case .chocolate: colors = ("#A97050", "#ECC199", 170)
        case .stone: colors = ("#A6B3CA", "#E4EAF3", 185)
        case .metal: colors = ("#B9DCED", "#FFF1AA", 170)
        case .jelly: colors = ("#FF91CE", "#FFE5F5", 110)
        case .cream: colors = ("#FFF0CF", "#FFFFFF", 70)
        case .fruit: colors = ("#FFD892", "#FFF9D1", 130)
        }
        return .init(material: material, tint: colors.0, secondary: colors.1,
            gravity: worldID == "coral" ? -18 : worldID == "galaxy" ? -8 : colors.2,
            hitDuration: [.honey, .jelly].contains(material) ? 0.28 : 0.20,
            destructionDuration: [.firefly, .lantern, .water].contains(material) ? 0.48 : 0.35)
    }
}
