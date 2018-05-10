import UIKit

struct TextAlertState: StateContainer {
	let parentUuid: UUID
	let recordingUuid: UUID?
	let dialogText: Var<String>
	
	init (parentUuid: UUID, recordingUuid: UUID? = nil) {
		self.parentUuid = parentUuid
		self.recordingUuid = recordingUuid
		self.dialogText = Var("")
	}
	var childValues: [StateContainer] { return [dialogText] }
}

func textAlert(_ text: TextAlertState, _ split: SplitState, _ store: StoreAdapter) -> AlertControllerConvertible {
	return AlertController(
		.willDisappear --> Input().map { _ in nil }.bind(to: split.textAlert),
		.title -- text.recordingUuid == nil ? .newFolder : .newRecording,
		.textFields -- [TextField(
			.placeholder -- text.recordingUuid == nil ? .folderName : .recordingName,
			.text <-- text.dialogText,
			.didChange --> Input().map { $0.text }.bind(to: text.dialogText)
		)],
		.actions -- [
			AlertAction(
				.title -- .create,
				.handler --> Input()
					.trigger(text.dialogText)
					.compactMap { (t: String) -> StoreAdapter.Message? in
						if let uuid = text.recordingUuid {
							return .addRecording(Recording(name: t, uuid: uuid, parentUuid: text.parentUuid))
						}
						return .newFolder(named: t, parentUuid: text.parentUuid)
					}.bind(to: store)
			),
			AlertAction(
				.title -- .cancel,
				.style -- .cancel,
				.handler --> Input()
					.compactMap { _ in text.recordingUuid == nil ? nil : .deleteTemporary }
					.bind(to: store)
			)
		],
		.preferredActionIndex -- 0
	)
}

fileprivate extension String {
	static let create = NSLocalizedString("Create", comment: "")
	static let cancel = NSLocalizedString("Cancel", comment: "")
	static let recordingName = NSLocalizedString("Name for the new recording", comment: "")
	static let newRecording = NSLocalizedString("New recording", comment: "")
	static let newFolder = NSLocalizedString("New folder", comment: "")
	static let folderName = NSLocalizedString("Name for the new folder", comment: "")
}
