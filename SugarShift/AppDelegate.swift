import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Generate the app icon PNG into the simulator's Documents folder
        // (DEBUG only). Path printed to console — drag it into AppIcon.appiconset.
        IconRenderer.dumpIfNeeded()

        let win = window ?? UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = SplashViewController()
        win.makeKeyAndVisible()
        window = win
        return true
    }
}
