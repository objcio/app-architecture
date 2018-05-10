import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	let driver = Driver<AppState, AppState.Message>(
		AppState(rootFolder: Store.shared.rootFolder),
		update: { state, message in state.update(message) },
		view: { state in state.viewController },
		subscriptions: { state in state.subscriptions })
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.rootViewController = driver.viewController
		window?.makeKeyAndVisible()
		window?.backgroundColor = .white
		return true
	}
	
	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}
	
	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		return true
	}
	
	func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
		driver.encodeRestorableState(coder)
	}
	
	func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
		driver.decodeRestorableState(coder)
	}
}
