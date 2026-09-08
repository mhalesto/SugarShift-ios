import SpriteKit
import UIKit

/// An adjustable background preference inside the existing settings scroller.
/// The host distinguishes a horizontal adjustment from a vertical scroll.
final class SettingsTransparencySlider: SKNode, UIAccessibilityIdentification {
    var accessibilityIdentifier: String?

    enum Surface: String, CaseIterable {
        case board, levelCard

        var title: String {
            switch self {
            case .board: return String(localized: "Board transparency")
            case .levelCard: return String(localized: "Level card transparency")
            }
        }

        var storedValue: Double {
            get {
                switch self {
                case .board: return Persistence.boardTransparency
                case .levelCard: return Persistence.levelCardTransparency
                }
            }
            nonmutating set {
                switch self {
                case .board: Persistence.boardTransparency = newValue
                case .levelCard: Persistence.levelCardTransparency = newValue
                }
            }
        }
    }

    static let rowHeight: CGFloat = 88
    var onChange: (() -> Void)?
    private let surface: Surface
    private let trackWidth: CGFloat
    private let trackY: CGFloat = -21
    private var value: Double
    private let valueLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let fill = SKSpriteNode(color: UIColor(hex: "#9C367D"), size: .zero)
    private let knob = SKShapeNode(circleOfRadius: 10)

    init(surface: Surface, width: CGFloat) {
        self.surface = surface
        trackWidth = width - 44
        value = surface.storedValue
        super.init()
        name = "settingsTransparency:\(surface.rawValue)"

        let background = SKShapeNode(rectOf: CGSize(width: width, height: Self.rowHeight), cornerRadius: 14)
        background.fillColor = UIColor(white: 0, alpha: 0.04)
        background.strokeColor = UIColor(white: 0, alpha: 0.06)
        background.lineWidth = 1
        addChild(background)

        valueLabel.fontSize = 13
        valueLabel.fontColor = UIColor(hex: "#7B255F")
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width / 2 - 14, y: 24)
        addChild(valueLabel)

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = surface.title
        title.fontSize = Persistence.largeText ? 16 : 15
        title.fontColor = UIColor(hex: "#0F172A")
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -width / 2 + 14, y: 24)
        while title.frame.width > width - 88 && title.fontSize > 10.5 { title.fontSize -= 0.5 }
        addChild(title)

        let caption = SKLabelNode(fontNamed: "AvenirNext-Medium")
        caption.text = String(localized: "Show more of the world behind it")
        caption.fontSize = 11
        caption.fontColor = UIColor(hex: "#64748B")
        caption.horizontalAlignmentMode = .left
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: -width / 2 + 14, y: 5)
        while caption.frame.width > width - 28 && caption.fontSize > 9 { caption.fontSize -= 0.5 }
        addChild(caption)

        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 6), cornerRadius: 3)
        track.fillColor = UIColor(hex: "#D9CBD8")
        track.strokeColor = .clear
        track.position.y = trackY
        addChild(track)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -trackWidth / 2, y: trackY)
        addChild(fill)
        knob.fillColor = .white
        knob.strokeColor = UIColor(hex: "#9C367D")
        knob.lineWidth = 2
        knob.position.y = trackY
        addChild(knob)

        isAccessibilityElement = true
        accessibilityLabel = surface.title
        accessibilityTraits = .adjustable
        accessibilityHint = String(localized: "Swipe up or down to adjust transparency.")
        accessibilityIdentifier = "settings.transparency.\(surface.rawValue)"
        refreshValue()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func acceptsTouch(at localPoint: CGPoint) -> Bool {
        CGRect(x: -trackWidth / 2 - 12, y: -Self.rowHeight / 2,
               width: trackWidth + 24, height: 44).contains(localPoint)
    }

    func adjust(at localPoint: CGPoint) {
        setValue(Double((localPoint.x + trackWidth / 2) / trackWidth))
    }

    override func accessibilityIncrement() { setValue(value + 0.05) }
    override func accessibilityDecrement() { setValue(value - 0.05) }

    private func setValue(_ proposed: Double) {
        guard proposed.isFinite else { return }
        let adjusted = (min(1, max(0, proposed)) * 20).rounded() / 20
        guard adjusted != value else { return }
        value = adjusted
        surface.storedValue = value
        refreshValue()
        onChange?()
    }

    private func refreshValue() {
        let percent = value.formatted(.percent.precision(.fractionLength(0)))
        valueLabel.text = percent
        accessibilityValue = percent
        fill.size = CGSize(width: trackWidth * CGFloat(value), height: 6)
        knob.position.x = -trackWidth / 2 + trackWidth * CGFloat(value)
    }
}
