import UIKit
import Foundation

/// AppDelegate to enforce portrait-only orientation throughout the app.
public class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
