import UIKit
import SpriteKit

/// Hosts the LevelMapScene with a soft animated pastel pink background and
/// presents the game when a level is tapped. On return from the game, the
/// scene reloads progress so newly earned stars and the next-level avatar
/// marker show up.
final class LevelMapViewController: UIViewController {

    private let gradient = CAGradientLayer()
    private var skView: SKView!
    private var scene: LevelMapScene!

    override func loadView() {
        let container = UIView()
        container.backgroundColor = UIColor(hex: "#FCE7F3")
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

        let scene = LevelMapScene(size: sk.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.onLevelSelected = { [weak self] level, daily in
            self?.startLevel(level, dailyChallenge: daily)
        }
        scene.onSettings      = { [weak self] in self?.showSettingsAlert() }
        scene.onShop          = { [weak self] in self?.showShopAlert() }
        sk.presentScene(scene)
        self.scene = scene

        Audio.shared.syncWithPreferences()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh stars / current level when returning from a level
        scene?.reloadProgress(animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    // MARK: - Gradient (pastel pink → lavender → mint)

    private func setupGradient() {
        let topPink   = UIColor(hex: "#FBCFE8").cgColor   // pastel pink
        let midPink   = UIColor(hex: "#FDE4F4").cgColor   // softer
        let lavender  = UIColor(hex: "#E9D5FF").cgColor   // lavender
        let mint      = UIColor(hex: "#BBF7D0").cgColor   // soft mint at bottom

        let altTop    = UIColor(hex: "#FCE7F3").cgColor
        let altMid    = UIColor(hex: "#F5D0FE").cgColor
        let altLav    = UIColor(hex: "#DDD6FE").cgColor
        let altMint   = UIColor(hex: "#A7F3D0").cgColor

        gradient.frame = view.bounds
        gradient.colors = [topPink, midPink, lavender, mint]
        gradient.locations = [0.0, 0.32, 0.65, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.5, y: 1.0)
        view.layer.insertSublayer(gradient, at: 0)

        let colorAnim = CABasicAnimation(keyPath: "colors")
        colorAnim.fromValue = [topPink, midPink, lavender, mint]
        colorAnim.toValue   = [altTop,  altMid,  altLav,   altMint]
        colorAnim.duration = 9
        colorAnim.autoreverses = true
        colorAnim.repeatCount = .infinity
        colorAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(colorAnim, forKey: "colors")
    }

    // MARK: - Navigation

    func startOpeningLevelIfEligible() {
        guard presentedViewController == nil, Persistence.highestUnlockedLevel == 1,
              !CampaignProgress.isCompleted(level: 1) else { return }
        startLevel(1, dailyChallenge: nil)
    }

    private func startLevel(_ n: Int, dailyChallenge: DailyChallenge?) {
        let game = GameViewController()
        game.levelNumber = n
        game.dailyChallenge = dailyChallenge
        game.modalTransitionStyle = .crossDissolve
        game.modalPresentationStyle = .fullScreen
        game.onChooseLevel = { [weak self] in
            self?.dismiss(animated: true)
        }
        present(game, animated: true)
    }

    private func showSettingsAlert() {
        scene.openSettings()
    }

    private func showShopAlert() {
        scene.openShop()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
