import UIKit

struct StoreContext {
	let documentStore: DocumentStore
	let viewStateStore: ViewStateStore
}

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate, UINavigationControllerDelegate {
	var context: StoreContext! { willSet { precondition(!isViewLoaded) } }

	var observations = Observations()
	var state = SplitViewState()
	
	var masterViewNavigationController: UINavigationController {
		return self.viewControllers.first as! UINavigationController
	}
	
	override func loadView() {
		super.loadView()

		let masterViewController = masterViewNavigationController.topViewController as! FolderViewController
		masterViewController.context = context.folderContext(index: 0)
		let detailViewController = (self.viewControllers.last as! UINavigationController).topViewController as! PlayViewController
		detailViewController.context = context
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.preferredDisplayMode = .allVisible
		self.delegate = self
		let detailViewController = (self.viewControllers.last as? UINavigationController)?.topViewController
		detailViewController?.navigationItem.leftBarButtonItem = displayModeButtonItem
		masterViewNavigationController.delegate = self

		observations += context.viewStateStore.addObserver(actionType: SplitViewState.Action.self) { [unowned self] state, action in
			self.state = state
			self.synchronizeMasterNavigationController(action)
			self.synchronizeDetail(action)
			self.synchronizeModalAlerts(action)
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case .showDetail?, .showDetailWithoutAnimation?:
			((segue.destination as! UINavigationController).topViewController as! PlayViewController).context = context
		case .showRecorder?:
			(segue.destination as! RecordViewController).context = context
		default: break
		}
	}

	func synchronizeMasterNavigationController(_ action: SplitViewState.Action?) {
		switch action {
		case .pushFolderView?:
			let fvc = storyboard!.instantiateViewController(withIdentifier: .folderIdentifier) as! FolderViewController
			fvc.context = context.folderContext(index: state.folderViews.endIndex - 1)
			masterViewNavigationController.pushViewController(fvc, animated: true)
		case .popFolderView?:
			let expectedDepth = state.folderViews.endIndex
			let targetVC = masterViewNavigationController.viewControllers[expectedDepth - 1]
			masterViewNavigationController.popToViewController(targetVC, animated: true)
		case nil:
			masterViewNavigationController.viewControllers = state.folderViews.indices.map { index in
				let fvc = storyboard!.instantiateViewController(withIdentifier: .folderIdentifier) as! FolderViewController
				fvc.context = context.folderContext(index: index)
				return fvc
			}
		default:
			break
		}
	}
	
	func synchronizeModalAlerts(_ action: SplitViewState.Action?) {
		switch action {
		case .showRecordView?:
			self.performSegue(withIdentifier: .showRecorder, sender: self)
		case .showTextAlert?:
			if state.textAlert?.recordingUUID != nil {
				present(TextAlertController.saveRecordingDialog(context: context), animated: true, completion: nil)
			} else {
				present(TextAlertController.newFolderDialog(context: context), animated: true, completion: nil)
			}
		case .dismissTextAlert?:
			guard presentedViewController is TextAlertController else { break }
			dismiss(animated: true, completion: nil)
		case .dismissRecordView?:
			guard presentedViewController is RecordViewController else { break }
			dismiss(animated: true, completion: nil)
		case nil where self.view.window != nil:
			if state.recordView != nil {
				self.performSegue(withIdentifier: .showRecorder, sender: self)
			} else if state.textAlert?.recordingUUID != nil {
				present(TextAlertController.saveRecordingDialog(context: context), animated: false, completion: nil)
			} else if state.textAlert != nil {
				present(TextAlertController.newFolderDialog(context: context), animated: false, completion: nil)
			} else if presentedViewController != nil {
				dismiss(animated: false, completion: nil)
			}
		default:
			break
		}
	}

	func synchronizeDetail(_ action: SplitViewState.Action?) {
		switch action {
		case .changedPlaySelection?:
			self.performSegue(withIdentifier: .showDetail, sender: self)
		case nil where state.playView.uuid != nil:
			self.performSegue(withIdentifier: .showDetailWithoutAnimation, sender: self)
		default: 
			break
		}
	}
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		guard animated else { return }
		
		let detailOnTop = navigationController.viewControllers.last is UINavigationController
		if self.isCollapsed && !detailOnTop {
			// The detail view is dismissed, clear associated state
			context.viewStateStore.setPlaySelection(nil, alreadyApplied: true)
		}
		
		let newDepth = navigationController.viewControllers.count - (detailOnTop ? 1 : 0)
		if newDepth < state.folderViews.count {
			// Handle the navigation bar back button 
			context.viewStateStore.popToNewDepth(newDepth, alreadyApplied: true)
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Need to re-synchronize the presentation of modal alerts after appearing since we can't present them until this point.
		synchronizeModalAlerts(nil)
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		if context.viewStateStore.content.playView.uuid == nil {
			// Don't include an empty player in the navigation stack when collapsed
			return true
		}
		return false
	}
}

fileprivate extension String {
	static let folderIdentifier = "folderViewController"
	static let showRecorder = "showRecorder"
	static let pushFolder = "pushFolder"
	static let showDetail = "showDetail"
	static let showDetailWithoutAnimation = "showDetailWithoutAnimation"
}

