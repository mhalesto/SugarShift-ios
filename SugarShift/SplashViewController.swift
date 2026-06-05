import UIKit
import SpriteKit

/// Splash screen: dreamy pastel gradient with a SpriteKit overlay running the
/// brand logo + falling/smashing fruit animation. Auto-transitions to the game.
final class SplashViewController: UIViewController {

    private let gradient = CAGradientLayer()
    private var skView: SKView!
    private var hasTransitioned = false

    override func loadView() {
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
        sk.ignoresSiblingOrder = true
        view.addSubview(sk)
        skView = sk

        let scene = SplashScene(size: sk.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.onReady = { [weak self] in self?.transitionToGame() }
        sk.presentScene(scene)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    // MARK: - Dreamy pastel gradient

    private func setupGradient() {
        // Pastel palette: pink → lavender → mint → peach
        let pinkA   = UIColor(hex: "#FBCFE8").cgColor
        let lavA    = UIColor(hex: "#DDD6FE").cgColor
        let mintA   = UIColor(hex: "#A7F3D0").cgColor
        let peachA  = UIColor(hex: "#FED7AA").cgColor

        let pinkB   = UIColor(hex: "#FCE7F3").cgColor
        let lavB    = UIColor(hex: "#EDE9FE").cgColor
        let mintB   = UIColor(hex: "#BBF7D0").cgColor
        let peachB  = UIColor(hex: "#FFE4C7").cgColor

        gradient.frame = view.bounds
        gradient.colors = [pinkA, lavA, mintA, peachA]
        gradient.locations = [0.0, 0.4, 0.7, 1.0]
        gradient.startPoint = CGPoint(x: 0.1, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.9, y: 1.0)
        view.layer.insertSublayer(gradient, at: 0)

        let colorAnim = CABasicAnimation(keyPath: "colors")
        colorAnim.fromValue = [pinkA, lavA, mintA, peachA]
        colorAnim.toValue   = [pinkB, lavB, mintB, peachB]
        colorAnim.duration = 6
        colorAnim.autoreverses = true
        colorAnim.repeatCount = .infinity
        colorAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(colorAnim, forKey: "colors")

        let startAnim = CABasicAnimation(keyPath: "startPoint")
        startAnim.fromValue = CGPoint(x: 0.1, y: 0.0)
        startAnim.toValue   = CGPoint(x: 0.9, y: 0.1)
        startAnim.duration = 10
        startAnim.autoreverses = true
        startAnim.repeatCount = .infinity
        startAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(startAnim, forKey: "start")

        let endAnim = CABasicAnimation(keyPath: "endPoint")
        endAnim.fromValue = CGPoint(x: 0.9, y: 1.0)
        endAnim.toValue   = CGPoint(x: 0.1, y: 0.9)
        endAnim.duration = 10
        endAnim.autoreverses = true
        endAnim.repeatCount = .infinity
        endAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(endAnim, forKey: "end")
    }

    // MARK: - Transition

    private func transitionToGame() {
        guard !hasTransitioned else { return }
        hasTransitioned = true

        let home = HomeViewController()
        home.modalTransitionStyle = .crossDissolve
        home.modalPresentationStyle = .fullScreen

        // Fade the splash content out gently before swapping
        UIView.animate(withDuration: 0.45, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            // Replace the window's root rather than presenting modally — clean stack
            guard let window = self.view.window else {
                self.present(home, animated: false)
                return
            }
            UIView.transition(with: window, duration: 0.45,
                              options: [.transitionCrossDissolve],
                              animations: {
                window.rootViewController = home
            })
        })
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
