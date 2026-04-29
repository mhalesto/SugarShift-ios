import UIKit
import SpriteKit

final class GameViewController: UIViewController {

    private let gradient = CAGradientLayer()
    private var skView: SKView!

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
        sk.ignoresSiblingOrder = true
        sk.showsFPS = false
        sk.showsNodeCount = false
        view.addSubview(sk)
        skView = sk

        let scene = GameScene(size: sk.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        sk.presentScene(scene)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
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
