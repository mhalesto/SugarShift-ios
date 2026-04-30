import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // App icon is now shipped via Assets.xcassets — no runtime regen needed.
        // To iterate the icon design, run:
        //   swift /tmp/render_sugarshift_icon.swift
        // …which overwrites Assets.xcassets/AppIcon.appiconset/AppIcon.png in place.

        let win = window ?? UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = SplashViewController()
        win.makeKeyAndVisible()
        window = win
        return true
    }
}
