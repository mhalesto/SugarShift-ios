import UIKit

/// Owns the app's main window. Release always routes through splash; debug can
/// use launch shortcuts for screenshots and iteration.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        #if DEBUG
        if let marketingScene = SugarShiftMarketingSceneKind.current {
            window.rootViewController = SugarShiftMarketingShowcaseViewController(kind: marketingScene)
        } else if UserDefaults.standard.integer(forKey: "ss.dev.skipToLevel") > 0 {
            let debugLevel = UserDefaults.standard.integer(forKey: "ss.dev.skipToLevel")
            let game = GameViewController()
            game.levelNumber = debugLevel
            window.rootViewController = game
        } else if UserDefaults.standard.bool(forKey: "ss.dev.skipToMap") {
            window.rootViewController = LevelMapViewController()
        } else {
            window.rootViewController = SplashViewController()
        }
        #else
        window.rootViewController = SplashViewController()
        #endif
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Persistence.Cloud.push()
        WidgetBridge.syncSharedState()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Persistence.Cloud.push()
        // Live Activities can only be *started* while still foregrounded, so
        // the life timer is armed here rather than in didEnterBackground.
        WidgetBridge.syncSharedState()
        WidgetBridge.refreshLifeActivity()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Lives may have refilled while away — retire a stale island timer.
        WidgetBridge.refreshLifeActivity()
    }
}
