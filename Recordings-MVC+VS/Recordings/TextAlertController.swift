import UIKit

class TextAlertController: UIAlertController {
	var context: StoreContext! { willSet { precondition(!isViewLoaded) } }

	var observations = Observations()
	var state: TextAlertState?
	
	static func textAlert(context: StoreContext, title: String, accept: String = .ok, cancel: String = .cancel, placeholder: String, cancelCallback: @escaping (TextAlertState) -> Void = { _ in }, acceptCallback: @escaping (TextAlertState) -> Void) -> TextAlertController {
		let alert = TextAlertController(title: title, message: nil, preferredStyle: .alert)
		alert.context = context
		alert.addTextField { $0.placeholder = placeholder }
		alert.addAction(UIAlertAction(title: cancel, style: .cancel) { [weak alert] _ in
			guard let state = alert?.state else { return }
			cancelCallback(state)
			context.viewStateStore.dismissTextAlert()
		})
		alert.addAction(UIAlertAction(title: accept, style: .default) { [weak alert] _ in
			guard let state = alert?.state else { return }
			acceptCallback(state)
			context.viewStateStore.dismissTextAlert()
		})
		return alert
	}
	
	static func newFolderDialog(context: StoreContext) -> TextAlertController {
		return textAlert(context: context, title: .createFolder, accept: .create, placeholder: .folderName) { state in
			context.documentStore.newFolder(named: state.text, parentUUID: state.parentUUID)
		}
	}
	
	static func saveRecordingDialog(context: StoreContext) -> TextAlertController {
		return textAlert(context: context, title: .saveRecording, accept: .save, placeholder: .nameForRecording, cancelCallback: { state in
			if let uuid = state.recordingUUID, let url = context.documentStore.fileURL(for: uuid) {
				_ = try? FileManager.default.removeItem(at: url)
			}
		}, acceptCallback: { state in
			guard let recordingUUID = state.recordingUUID else { return }
			context.documentStore.addRecording(Recording(name: state.text, uuid: recordingUUID, parentUUID: state.parentUUID))
		})
	}
	
	override func viewDidLoad() {
		observations += context.viewStateStore.addObserver(actionType: TextAlertState.Action.self) { [unowned self] state, action in
			guard let ta = state.textAlert else { return }
			self.state = ta
			self.handleViewStateNotification(action)
		}
		NotificationCenter.default.addObserver(self, selector: #selector(textChanged(_:)), name: NSNotification.Name.UITextFieldTextDidChange, object: textFields?.first!)
	}
	
	func handleViewStateNotification(_ action: TextAlertState.Action?) {
		actions.last?.isEnabled = !(state?.text.isEmpty ?? true)
		if action == nil {
			textFields?.first?.text = state?.text
		}
	}

	@objc func textChanged(_ notification: Notification) {
		guard let text = textFields?.first?.text else { return }
		context.viewStateStore.updateAlertText(text)
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
	static let ok = NSLocalizedString("OK", comment: "")
	static let cancel = NSLocalizedString("Cancel", comment: "")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
}
