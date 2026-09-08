import SpriteKit
import UIKit

/// Original family portraits made from vector shapes, with no downloaded art.
/// Stable portrait/wardrobe IDs can later select richer art through this one API.
enum CharacterPortrait {
    static func make(character: CharacterDefinition,
                     expression: CharacterExpression = .warm,
                     size: CGFloat,
                     avatar: AvatarConfiguration = .starter) -> SKNode {
        let root = SKNode()
        let isGrandpa = character.role == .grandparent
        let isParent = character.role == .parent
        let skin = UIColor(hex: character.role == .player ? avatar.skin.colorHex : isGrandpa ? "#BA7954" : "#B56F4D")
        let hair = UIColor(hex: character.role == .player ? avatar.hair.colorHex : isGrandpa ? "#EEE4DD" : "#422738")
        let clothing = UIColor(hex: character.role == .player ? avatar.outfit.colorHex : isGrandpa ? "#DBA547" : "#4CA894")
        let ink = UIColor(hex: "#4A2C3F")

        if character.role == .player, let backpack = avatar.backpack {
            rounded(in: root, size: CGSize(width: 53, height: 40), radius: 10,
                    at: CGPoint(x: 0, y: -17), fill: UIColor(hex: backpack.colorHex))
        }

        ellipse(in: root, size: CGSize(width: 59, height: 8), at: CGPoint(x: 0, y: -49),
                fill: UIColor(hex: "#4F294E").withAlphaComponent(0.17))
        // Shoes, trousers, and hands make the avatar a reusable full figure.
        for side: CGFloat in [-1, 1] {
            rounded(in: root, size: CGSize(width: 14, height: 23), radius: 5,
                    at: CGPoint(x: side * 10, y: -35), fill: UIColor(hex: "#504665"))
            rounded(in: root, size: CGSize(width: 20, height: 10), radius: 4,
                    at: CGPoint(x: side * 11, y: -46),
                    fill: UIColor(hex: character.role == .player ? avatar.shoes.colorHex : "#735047"))
            let arm = rounded(in: root, size: CGSize(width: 13, height: 32), radius: 6,
                              at: CGPoint(x: side * 24, y: -18), fill: clothing)
            arm.zRotation = side * 0.14
            ellipse(in: root, size: CGSize(width: 12, height: 14), at: CGPoint(x: side * 26, y: -31), fill: skin)
        }
        rounded(in: root, size: CGSize(width: 43, height: 41), radius: 13,
                at: CGPoint(x: 0, y: -20), fill: clothing,
                stroke: clothing.withAlphaComponent(0.6))
        rounded(in: root, size: CGSize(width: 13, height: 17), radius: 4,
                at: CGPoint(x: 0, y: 0), fill: skin)

        if isGrandpa {
            rounded(in: root, size: CGSize(width: 13, height: 31), radius: 3,
                    at: CGPoint(x: 0, y: -15), fill: UIColor(hex: "#FFF4DC"))
            for y: CGFloat in [-11, -21, -31] {
                ellipse(in: root, size: CGSize(width: 3, height: 3), at: CGPoint(x: 5, y: y), fill: ink)
            }
            rounded(in: root, size: CGSize(width: 10, height: 9), radius: 2,
                    at: CGPoint(x: -12, y: -24), fill: UIColor(hex: "#B68035"))
        } else if isParent {
            let scarf = rounded(in: root, size: CGSize(width: 25, height: 9), radius: 4,
                                at: CGPoint(x: 0, y: -3), fill: UIColor(hex: "#FFE8B4"))
            scarf.zRotation = -0.1
            let tail = rounded(in: root, size: CGSize(width: 8, height: 20), radius: 3,
                               at: CGPoint(x: 10, y: -10), fill: UIColor(hex: "#FFD998"))
            tail.zRotation = -0.22
        } else {
            rounded(in: root, size: CGSize(width: 25, height: 12), radius: 4,
                    at: CGPoint(x: 0, y: -3), fill: UIColor(hex: "#FFF4D9"))
            for side: CGFloat in [-1, 1] {
                rounded(in: root, size: CGSize(width: 6, height: 19), radius: 2,
                        at: CGPoint(x: side * 10, y: -11), fill: clothing)
                ellipse(in: root, size: CGSize(width: 3, height: 3), at: CGPoint(x: side * 10, y: -11),
                        fill: UIColor(hex: "#FFE296"))
            }
            rounded(in: root, size: CGSize(width: 16, height: 11), radius: 4,
                    at: CGPoint(x: 0, y: -24), fill: clothing.withAlphaComponent(0.55),
                    stroke: UIColor.white.withAlphaComponent(0.35))
        }

        // Hair behind the face; Grandpa's temples and Mum's bun have distinct
        // silhouettes before any facial details are added.
        if isParent {
            rounded(in: root, size: CGSize(width: 53, height: 55), radius: 24,
                    at: CGPoint(x: 0, y: 19), fill: hair)
            ellipse(in: root, size: CGSize(width: 23, height: 23), at: CGPoint(x: 20, y: 36), fill: hair)
            ellipse(in: root, size: CGSize(width: 19, height: 5), at: CGPoint(x: 20, y: 33),
                    fill: UIColor(hex: "#ECA5B8"))
        } else {
            ellipse(in: root, size: CGSize(width: 50, height: 43), at: CGPoint(x: 0, y: 24), fill: hair)
        }
        for side: CGFloat in [-1, 1] {
            ellipse(in: root, size: CGSize(width: 10, height: 14), at: CGPoint(x: side * 23, y: 17), fill: skin)
        }
        ellipse(in: root, size: CGSize(width: 44, height: 45), at: CGPoint(x: 0, y: 18), fill: skin)
        ellipse(in: root, size: CGSize(width: 27, height: 28), at: CGPoint(x: -7, y: 23),
                fill: UIColor.white.withAlphaComponent(0.055))

        if isGrandpa {
            for side: CGFloat in [-1, 1] {
                let temple = ellipse(in: root, size: CGSize(width: 10, height: 19),
                                     at: CGPoint(x: side * 20, y: 29), fill: hair)
                temple.zRotation = side * -0.25
            }
            ellipse(in: root, size: CGSize(width: 23, height: 9), at: CGPoint(x: -8, y: 40), fill: hair)
        } else if character.role == .player && avatar.hair.id == "curls" {
            for index in 0..<6 {
                let x = CGFloat(index) * 7 - 18
                ellipse(in: root, size: CGSize(width: 16, height: 16),
                        at: CGPoint(x: x, y: 39 + (index % 2 == 0 ? 1 : -2)), fill: hair)
            }
        } else {
            let fringe = UIBezierPath()
            fringe.move(to: CGPoint(x: -23, y: 28))
            fringe.addCurve(to: CGPoint(x: 23, y: 29),
                            controlPoint1: CGPoint(x: -30, y: 58),
                            controlPoint2: CGPoint(x: 22, y: 52))
            fringe.addQuadCurve(to: CGPoint(x: 8, y: 35), controlPoint: CGPoint(x: 19, y: 34))
            fringe.addQuadCurve(to: CGPoint(x: -23, y: 28), controlPoint: CGPoint(x: -4, y: 25))
            shape(in: root, path: fringe, fill: hair)
        }

        // Eyes, brows, blush and mouth are expression-driven. No idle animation
        // is required for readability or for a reduced-motion presentation.
        for side: CGFloat in [-1, 1] {
            ellipse(in: root, size: CGSize(width: 8, height: 4), at: CGPoint(x: side * 15, y: 11),
                    fill: UIColor(hex: "#EC9A8B").withAlphaComponent(0.48))
            let wideEyes = [.curious, .surprised, .excited].contains(expression)
            ellipse(in: root, size: CGSize(width: 4.2, height: wideEyes ? 6.5 : expression == .laughing ? 2.5 : 5.2),
                    at: CGPoint(x: side * 9, y: 23), fill: ink)
            ellipse(in: root, size: CGSize(width: 1.2, height: 1.2), at: CGPoint(x: side * 9 - 0.6, y: 24.4), fill: .white)
            let brow = UIBezierPath()
            let raised: CGFloat = expression == .curious && side > 0 ? 3 : expression == .worried ? 2 : 0
            brow.move(to: CGPoint(x: side * 9 - 4, y: 30 + raised))
            brow.addQuadCurve(to: CGPoint(x: side * 9 + 4, y: 30 + raised),
                             controlPoint: CGPoint(x: side * 9, y: 32 + raised))
            shape(in: root, path: brow, stroke: isGrandpa ? hair : ink, lineWidth: isGrandpa ? 2.8 : 1.6)
        }
        ellipse(in: root, size: CGSize(width: 5.5, height: 6), at: CGPoint(x: 0, y: 16),
                fill: UIColor(hex: "#97573F").withAlphaComponent(0.35))
        let smile = UIBezierPath()
        smile.move(to: CGPoint(x: -6, y: 9))
        let dip: CGFloat = [.neutral, .thoughtful, .thinking].contains(expression) ? 7
            : [.sad, .worried, .angry].contains(expression) ? 14 : 2
        smile.addQuadCurve(to: CGPoint(x: 6, y: 9), controlPoint: CGPoint(x: 0, y: dip))
        shape(in: root, path: smile, stroke: ink, lineWidth: 1.6)
        if [.surprised, .excited, .laughing].contains(expression) {
            ellipse(in: root, size: CGSize(width: expression == .surprised ? 6 : 10, height: 8),
                    at: CGPoint(x: 0, y: 7), fill: ink)
        }

        if isGrandpa {
            for side: CGFloat in [-1, 1] {
                let moustache = ellipse(in: root, size: CGSize(width: 10, height: 4.5),
                                        at: CGPoint(x: side * 4.5, y: 11), fill: hair)
                moustache.zRotation = side * -0.22
            }
        }
        if isGrandpa || (avatar.glasses != nil || avatar.accessories.contains(where: { $0.id == "round-glasses" })) && character.role == .player {
            let glassesColor = isGrandpa ? UIColor(hex: "#745045")
                : UIColor(hex: avatar.glasses?.colorHex ?? avatar.accessories.first(where: { $0.id == "round-glasses" })?.colorHex ?? "#472D55")
            for side: CGFloat in [-1, 1] {
                ellipse(in: root, size: CGSize(width: 16, height: 15), at: CGPoint(x: side * 9, y: 23),
                        fill: UIColor.white.withAlphaComponent(0.06), stroke: glassesColor, lineWidth: 1.5)
            }
            let bridge = UIBezierPath()
            bridge.move(to: CGPoint(x: -1, y: 24))
            bridge.addLine(to: CGPoint(x: 1, y: 24))
            shape(in: root, path: bridge, stroke: glassesColor, lineWidth: 1.5)
        }
        if isParent {
            for side: CGFloat in [-1, 1] {
                ellipse(in: root, size: CGSize(width: 3, height: 4), at: CGPoint(x: side * 23, y: 10),
                        fill: UIColor(hex: "#FFD880"))
            }
        }
        if character.role == .player, let hat = avatar.hat {
            rounded(in: root, size: CGSize(width: 38, height: 16), radius: 7,
                    at: CGPoint(x: 0, y: 45), fill: UIColor(hex: hat.colorHex))
            ellipse(in: root, size: CGSize(width: 58, height: 7), at: CGPoint(x: 0, y: 39),
                    fill: UIColor(hex: hat.colorHex))
        }
        root.setScale(max(1, size) / 100)
        root.isAccessibilityElement = true
        root.accessibilityLabel = "\(character.displayName). \(character.relationship)"
        return root
    }

    @discardableResult
    private static func ellipse(in root: SKNode, size: CGSize, at point: CGPoint,
                                fill: UIColor, stroke: UIColor = .clear,
                                lineWidth: CGFloat = 1) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: size)
        node.position = point
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        root.addChild(node)
        return node
    }

    @discardableResult
    private static func rounded(in root: SKNode, size: CGSize, radius: CGFloat,
                                at point: CGPoint, fill: UIColor,
                                stroke: UIColor = .clear) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.position = point
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1
        root.addChild(node)
        return node
    }

    private static func shape(in root: SKNode, path: UIBezierPath, fill: UIColor = .clear,
                              stroke: UIColor = .clear, lineWidth: CGFloat = 1) {
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        node.lineCap = .round
        root.addChild(node)
    }
}
