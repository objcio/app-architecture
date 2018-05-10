import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	var historyViewController: HistoryViewController?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		setContextOnSplitViewIfNeeded()
		#if false
			// Set this condition to `true` to enable the time-travel slider at the bottom of the
			// user-interface.
			// "Time-travel" is the idea that you can record a snap-shot of the view-state and
			// document-state every time something changes and then wind these snapshots forwards
			// and backwards to replay the user-interface.
			DispatchQueue.main.async {
				// Wait until *after* the main window is presented and
				// then create a new window over the top.
				self.historyViewController = HistoryViewController(nibName: nil, bundle: nil)
			}
		#endif
		return true
	}
	
	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}
	
	func setContextOnSplitViewIfNeeded() {
		let splitVC = window?.rootViewController as! SplitViewController
		if splitVC.context == nil {
			splitVC.context = StoreContext(documentStore: .shared, viewStateStore: .shared)
		}
	}
	
	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		setContextOnSplitViewIfNeeded()
		return true
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		ViewStateStore.shared.dismissRecording()
	}
	
	func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
		guard let data = try? ViewStateStore.shared.serialized() else { return }
		if ViewStateStore.shared.enableDebugLogging {
			print("Encoding for restoration: \(String(decoding: data, as: UTF8.self))")
		}
		coder.encode(data, forKey: .viewStateKey)
	}
	
	func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
		guard let data = coder.decodeObject(forKey: .viewStateKey) as? Data else { return }
		ViewStateStore.shared.reloadAndNotify(jsonData: data)
	}
}

fileprivate extension String {
	static let viewStateKey = "viewState"
}
