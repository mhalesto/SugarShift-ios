import UIKit
import SpriteKit

/// Landing/home page hosting the HomeScene over an animated pastel pink → mint
/// gradient. The PLAY button advances to the level map.
final class HomeViewController: UIViewController {

    private let gradient = CAGradientLayer()
    private var skView: SKView!
    private var scene: HomeScene!

    override func loadView() {
        let container = UIView()
        container.backgroundColor = UIColor(hex: "#FBCFE8")
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGradient()

        let sk = SKView(frame: view.bounds)
        sk.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sk.allowsTransparency = true
        sk.backgroundColor = .clear
        sk.ignoresSiblingOrder = true
        view.addSubview(sk)
        skView = sk

        let scene = HomeScene(size: sk.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.onPlay = { [weak self] in self?.openLevelMap() }
        scene.onOpeningFinished = { [weak self] in self?.openLevelMap(startOpeningLevel: true) }
        sk.presentScene(scene)
        self.scene = scene

        Audio.shared.syncWithPreferences()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    // MARK: - Gradient (sky pink → lavender → soft sky blue)

    private func setupGradient() {
        let topPink   = UIColor(hex: "#FBCFE8").cgColor
        let midPink   = UIColor(hex: "#FDE4F4").cgColor
        let lavender  = UIColor(hex: "#DDD6FE").cgColor
        let sky       = UIColor(hex: "#BAE6FD").cgColor

        let altTop    = UIColor(hex: "#FCE7F3").cgColor
        let altMid    = UIColor(hex: "#F5D0FE").cgColor
        let altLav    = UIColor(hex: "#E9D5FF").cgColor
        let altSky    = UIColor(hex: "#A7F3D0").cgColor

        gradient.frame = view.bounds
        gradient.colors = [topPink, midPink, lavender, sky]
        gradient.locations = [0.0, 0.32, 0.65, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.5, y: 1.0)
        view.layer.insertSublayer(gradient, at: 0)

        let colorAnim = CABasicAnimation(keyPath: "colors")
        colorAnim.fromValue = [topPink, midPink, lavender, sky]
        colorAnim.toValue   = [altTop,  altMid,  altLav,   altSky]
        colorAnim.duration = 9
        colorAnim.autoreverses = true
        colorAnim.repeatCount = .infinity
        colorAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(colorAnim, forKey: "colors")
    }

    // MARK: - Navigation

    private func openLevelMap(startOpeningLevel: Bool = false) {
        guard presentedViewController == nil else { return }
        let map = LevelMapViewController()
        map.modalTransitionStyle = .crossDissolve
        map.modalPresentationStyle = .fullScreen
        present(map, animated: true) {
            if startOpeningLevel { map.startOpeningLevelIfEligible() }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
