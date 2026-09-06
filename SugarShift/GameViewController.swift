import UIKit
import SpriteKit

final class GameViewController: UIViewController {

    /// Level selected by the map. If nil, the scene falls back to persisted
    /// progression.
    var levelNumber: Int?
    /// Non-nil only when the level was launched from the daily challenge card.
    /// Capturing the full value keeps a run stable across local midnight.
    var dailyChallenge: DailyChallenge?

    /// Called when the player taps "Choose level" on the end-of-level card.
    /// The host (LevelMapViewController) typically dismisses this VC to return
    /// to the level map.
    var onChooseLevel: (() -> Void)?

    private let gradient = CAGradientLayer()
    private var skView: SKView!
    private var didPresentScene = false

    override func loadView() {
        // Replace the storyboard's SKView root with a plain UIView so the
        // gradient layer can sit behind a transparent SKView (sublayers of
        // an SKView render *above* its Metal content, not behind it).
        let container = UIView()
        container.backgroundColor = .black
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGradient()

        let sk = SKView(frame: view.bounds)
        sk.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sk.allowsTransparency = true
        sk.backgroundColor = .clear
        sk.ignoresSiblingOrder = false
        sk.showsFPS = false
        sk.showsNodeCount = false
        view.addSubview(sk)
        skView = sk
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
        presentGameSceneIfNeeded()
    }

    private func presentGameSceneIfNeeded() {
        guard !didPresentScene else { return }
        guard skView.bounds.width > 0, skView.bounds.height > 0 else { return }
        didPresentScene = true

        let scene = GameScene(size: skView.bounds.size)
        scene.initialLevel = levelNumber
        scene.initialDailyChallenge = dailyChallenge
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.onChooseLevel = { [weak self] in
            guard let self else { return }
            if let onChooseLevel = self.onChooseLevel { onChooseLevel() }
            else if let window = self.view.window {
                window.rootViewController = LevelMapViewController()
            }
        }
        skView.presentScene(scene)
    }

    private func setupGradient() {
        let topAqua    = UIColor(hex: "#86DCDC")
        let midTeal    = UIColor(hex: "#4FB3B3")
        let bottomBlue = UIColor(hex: "#5BA9C7")
        let altTop     = UIColor(hex: "#9FE7E0")
        let altMid     = UIColor(hex: "#5DC4BD")
        let altBottom  = UIColor(hex: "#6FB7D0")

        gradient.frame = view.bounds
        gradient.colors = [topAqua.cgColor, midTeal.cgColor, bottomBlue.cgColor]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.2, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.8, y: 1.0)
        view.layer.insertSublayer(gradient, at: 0)

        let colorAnim = CABasicAnimation(keyPath: "colors")
        colorAnim.fromValue = [topAqua.cgColor, midTeal.cgColor, bottomBlue.cgColor]
        colorAnim.toValue   = [altTop.cgColor,  altMid.cgColor,  altBottom.cgColor]
        colorAnim.duration = 8
        colorAnim.autoreverses = true
        colorAnim.repeatCount = .infinity
        colorAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(colorAnim, forKey: "gradientColors")

        let startAnim = CABasicAnimation(keyPath: "startPoint")
        startAnim.fromValue = CGPoint(x: 0.2, y: 0.0)
        startAnim.toValue   = CGPoint(x: 0.8, y: 0.05)
        startAnim.duration = 12
        startAnim.autoreverses = true
        startAnim.repeatCount = .infinity
        startAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(startAnim, forKey: "gradientStart")

        let endAnim = CABasicAnimation(keyPath: "endPoint")
        endAnim.fromValue = CGPoint(x: 0.8, y: 1.0)
        endAnim.toValue   = CGPoint(x: 0.2, y: 0.95)
        endAnim.duration = 12
        endAnim.autoreverses = true
        endAnim.repeatCount = .infinity
        endAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(endAnim, forKey: "gradientEnd")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
