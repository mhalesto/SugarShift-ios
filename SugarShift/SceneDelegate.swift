import UIKit

/// Owns the app's main window. Routes the launch into the splash screen unless
/// the dev flag `ss.dev.skipToMap` is set, in which case it lands directly in
/// the level map (used for screenshots/iteration).
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
        } else if let debugLevel = UserDefaults.standard.object(forKey: "ss.dev.skipToLevel") as? Int {
            let game = GameViewController()
            game.levelNumber = debugLevel
            window.rootViewController = game
        } else if UserDefaults.standard.bool(forKey: "ss.dev.skipToMap") {
            window.rootViewController = LevelMapViewController()
        } else {
            window.rootViewController = SplashViewController()
        }
        #else
        if UserDefaults.standard.bool(forKey: "ss.dev.skipToMap") {
            window.rootViewController = LevelMapViewController()
        } else {
            window.rootViewController = SplashViewController()
        }
        #endif
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Persistence.Cloud.push()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Persistence.Cloud.push()
    }
}
