import UIKit

struct SplitState: StateContainer {
	let navStack: StackAdapter<FolderState>
	let playState: Var<PlayState?>
	let textAlert: Var<TextAlertState?>
	
	let splitButton = TempVar<BarButtonItemConvertible?>()
	let recordState = TempVar<RecordState?>()
	let lastSelectedRecordingUuid = TempVar<UUID>()
	
	init() {
		navStack = StackAdapter([FolderState(folderUuid: Store.rootFolderUuid)])
		playState = Var(nil)
		textAlert = Var<TextAlertState?>(nil)
	}
	var childValues: [StateContainer] { return [navStack, playState, textAlert] }
}

func splitView(_ split: SplitState, _ store: StoreAdapter) -> ViewControllerConvertible {
	return SplitViewController(
		.preferredDisplayMode -- .allVisible,
		.primaryViewController -- primaryView(split, store),
		.secondaryViewController -- secondaryView(split, store),
		.dismissedSecondary --> Input().map { nil }.bind(to: split.playState),
		.shouldShowSecondary <-- split.playState.map { ps in ps != nil },
		.displayModeButton --> split.splitButton,
		.present <-- split.recordState
			.modalPresentation { recState in recordView(recState, split, store) }
			.mergeWith(
				split.textAlert.modalPresentation { textState in textAlert(textState, split, store) }
			),
		.cancelOnClose -- [
			store.temporarySignal()
				.compactMap { possibleDetails in RecordState(tempFile: possibleDetails) }
				.cancellableBind(to: split.recordState),
			store.temporarySignal()
				.filter { possibleDetails in possibleDetails?.isRecorded ?? true }
				.map { possibleDetails in
					possibleDetails.map { details in
						TextAlertState(parentUuid: details.parentUuid, recordingUuid: details.uuid)
					}
				}
				.cancellableBind(to: split.textAlert),
			split.lastSelectedRecordingUuid
				.flatMapLatest { uuid in
					store.recordingSignal(uuid)
						.map { recAndUrl in PlayState(uuid: uuid, url: recAndUrl.url) }
						.endWith(nil)
				}
				.cancellableBind(to: split.playState)
		]
	)
}

private func primaryView(_ split: SplitState, _ store: StoreAdapter) -> NavigationControllerConvertible {
	return NavigationController(
		.navigationBar -- navBarStyles(),
		.stack <-- split.navStack.stackMap { return folderView($0, split, store) },
		.poppedToCount --> split.navStack.poppedToCount
	)
}

private func secondaryView(_ split: SplitState, _ store: StoreAdapter) -> NavigationControllerConvertible {
	return NavigationController(
		.navigationBar -- navBarStyles(),
		.stack <-- split.playState
			.distinctUntilChanged { prev, cur in prev?.uuid == cur?.uuid }
			.map { playState in
				guard let ps = playState else { return [emptyDetailViewController(split)] }
				return [playView(ps, split, store)]
			}
	)
}

private func navBarStyles() -> NavigationBar {
	return NavigationBar(
		.titleTextAttributes -- [.foregroundColor: UIColor.white],
		.tintColor -- .orangeTint,
		.barTintColor -- .blueTint
	)
}

func emptyDetailViewController(_ split: SplitState) -> ViewControllerConvertible {
	return ViewController(
		.view -- View(.backgroundColor -- UIColor.white),
		.navigationItem -- NavigationItem(
			.leftBarButtonItems <-- split.splitButton.optionalToArray().animate(.none)
		),
		.layout -- .vertical(align: .center,
			.space(),
			.view(Label(.text -- .noRecordingSelected, .isEnabled -- false)),
			.space(.fillRemaining)
		)
	)
}

fileprivate extension String {
	static let noRecordingSelected = NSLocalizedString("No recording selected.", comment: "")
}

