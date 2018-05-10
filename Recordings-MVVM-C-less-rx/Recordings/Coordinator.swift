import UIKit

final class Coordinator {
	let splitViewController: UISplitViewController
	let storyboard = UIStoryboard(name: "Main", bundle: nil)
	
	var folderNavigationController: UINavigationController {
		return splitViewController.viewControllers[0] as! UINavigationController
	}
	
	init(_ splitView: UISplitViewController) {
		self.splitViewController = splitView
		self.splitViewController.loadViewIfNeeded()
		
		let folderVC = folderNavigationController.viewControllers.first as! FolderViewController
		folderVC.delegate = self
		folderVC.viewModel.folder = Store.shared.rootFolder
		folderVC.navigationItem.leftItemsSupplementBackButton = true
		folderVC.navigationItem.leftBarButtonItem = folderVC.editButtonItem
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		guard let folder = notification.object as? Folder,
			notification.userInfo?[Item.changeReasonKey] as? String == Item.removed
		else { return }
		updateForRemoval(of: folder)
	}
	
	func updateForRemoval(of folder: Folder) {
		let folderVCs = folderNavigationController.viewControllers as! [FolderViewController]
		guard let index = folderVCs.index(where: { $0.viewModel.folder === folder }) else { return }
		let previousIndex = index > 0 ? index - 1 : index
		folderNavigationController.popToViewController(folderVCs[previousIndex], animated: true)
	}
}

extension Coordinator: FolderViewControllerDelegate {
	func didSelect(_ item: Item) {
		switch item {
		case let recording as Recording:
			let playerNC = storyboard.instantiatePlayerNavigationController(with: recording, leftBarButtonItem: splitViewController.displayModeButtonItem)
			splitViewController.showDetailViewController(playerNC, sender: self)
		case let folder as Folder:
			let folderVC = storyboard.instantiateFolderViewController(with: folder, delegate: self)
			folderNavigationController.pushViewController(folderVC, animated: true)
		default: fatalError()
		}
	}
	
	func createRecording(in folder: Folder) {
		let recordVC = storyboard.instantiateRecordViewController(with: folder, delegate: self)
		recordVC.modalPresentationStyle = .formSheet
		recordVC.modalTransitionStyle = .crossDissolve
		splitViewController.present(recordVC, animated: true)
	}
}

extension Coordinator: RecordViewControllerDelegate {
	func finishedRecording(_ recordVC: RecordViewController) {
		recordVC.dismiss(animated: true)
	}
}


extension UIStoryboard {
	func instantiatePlayerNavigationController(with recording: Recording, leftBarButtonItem: UIBarButtonItem) -> UINavigationController {
		let playerNC = instantiateViewController(withIdentifier: "playerNavigationController") as! UINavigationController
		let playerVC = playerNC.viewControllers[0] as! PlayViewController
		playerVC.viewModel.recording = recording
		playerVC.navigationItem.leftBarButtonItem = leftBarButtonItem
		playerVC.navigationItem.leftItemsSupplementBackButton = true
		return playerNC
	}
	
	func instantiateFolderViewController(with folder: Folder, delegate: FolderViewControllerDelegate) -> FolderViewController {
		let folderVC = instantiateViewController(withIdentifier: "folderController") as! FolderViewController
		folderVC.viewModel.folder = folder
		folderVC.delegate = delegate
		folderVC.navigationItem.leftItemsSupplementBackButton = true
		folderVC.navigationItem.leftBarButtonItem = folderVC.editButtonItem
		return folderVC
	}
	
	func instantiateRecordViewController(with folder: Folder, delegate: RecordViewControllerDelegate) -> RecordViewController {
		let recordVC = instantiateViewController(withIdentifier: "recorderViewController") as! RecordViewController
		recordVC.viewModel.folder = folder
		recordVC.delegate = delegate
		return recordVC
	}
}
