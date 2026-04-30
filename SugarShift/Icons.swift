import SpriteKit
import UIKit

/// Centralised SF Symbol → SKSpriteNode helper so every HUD icon shares one
/// look (weight, rendering, alignment).
enum Icons {

    /// Common symbol names used across the HUD. Keep them in one place so we can
    /// rename or restyle without hunting through call sites.
    enum Name {
        // Filled where the icon is *the* feature on a colored background
        // (and reads better solid). Outlined where the chrome should feel
        // light and soft.
        static let life       = "heart.fill"        // sits inside pink lives pill / Life booster
        static let level      = "bolt.fill"         // bright yellow accent next to "Level N"
        static let goal       = "scope"             // crosshair on the goal pill
        static let settings   = "gearshape"         // outlined gear
        static let cart       = "cart"              // outlined cart
        static let cash       = "banknote"          // outlined banknote on cash pill
        static let cashFilled = "banknote.fill"     // filled mini banknote in chip
        static let plus       = "plus"

        static let star       = "star.fill"
        static let starHollow = "star"

        static let hammer     = "hammer"            // outlined hammer
        static let swap       = "hand.raised"       // outlined hand (smaller visual mass)
        static let shuffle    = "shuffle"
        static let extraMoves = "bolt.fill"         // bright yellow bolt inside pink circle

        static let chevronLeft = "chevron.left"
    }

    /// Build a tinted SKSpriteNode from an SF Symbol.
    ///
    /// Forces **monochrome** rendering so the `tint` is actually respected — many
    /// symbols (banknote.fill, hammer.fill, hand.raised.fill, …) ship as
    /// multicolor by default on iOS 16+, and `.alwaysOriginal` keeps that
    /// multicolor data, ignoring your tint.
    static func sprite(_ symbol: String,
                       size: CGFloat,
                       weight: UIImage.SymbolWeight = .bold,
                       tint: UIColor = .white) -> SKSpriteNode {
        var cfg = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        if #available(iOS 16.0, *) {
            cfg = cfg.applying(UIImage.SymbolConfiguration.preferringMonochrome())
        }
        let base = UIImage(systemName: symbol, withConfiguration: cfg) ?? UIImage()
        let tinted = base.withTintColor(tint, renderingMode: .alwaysOriginal)
        let texture = SKTexture(image: tinted)
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = tinted.size
        return sprite
    }
}
