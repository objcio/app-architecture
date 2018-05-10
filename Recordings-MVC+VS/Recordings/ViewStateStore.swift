import Foundation

final class ViewStateStore: NotifyingStore {
	static let shared = ViewStateStore()
	static let shortName = "ViewState"
	let remoteDebugger = RemoteDebugger()
	
	var persistToUrl: URL? { return nil }
	var content = SplitViewState() {
		didSet {
			remoteDebugger.write(jsonData: try! JSONEncoder().encode(content))
		}
	}
	init() {
	}

	var splitView: SplitViewState { return content }
	var folderViews: [FolderViewState] { return content.folderViews }
	var playView: PlayViewState { return content.playView }
	var recordView: RecordViewState? { return content.recordView }
	var textAlert: TextAlertState? { return content.textAlert }

	func loadWithoutNotifying(jsonData: Data) {
		do {
			content = try JSONDecoder().decode(DataType.self, from: jsonData)
		} catch {
			print("Failed to load. \(error)")
		}
	}
	
	func setPlaySelection(_ uuid: UUID?, alreadyApplied: Bool) {
		content.playView = PlayViewState(uuid: uuid)
		commitAction(alreadyApplied ? SplitViewState.Action.alreadyDismissedDetailView : SplitViewState.Action.changedPlaySelection)
	}

	func pushFolder(_ uuid: UUID) {
		content.folderViews.append(FolderViewState(uuid: uuid))
		commitAction(SplitViewState.Action.pushFolderView)
	}

	func popToNewDepth(_ newDepth: Int, alreadyApplied: Bool) {
		let popDepth = max(1, min(content.folderViews.count, newDepth), newDepth)
		content.folderViews.removeLast(content.folderViews.count - popDepth)
		commitAction(alreadyApplied ? SplitViewState.Action.alreadyPoppedFolderView : SplitViewState.Action.popFolderView)
	}
	
	func updateScrollPosition(folderUUID: UUID, scrollPosition: Double) {
		guard let index = content.folderViews.index(where: { $0.folderUUID == folderUUID }) else { return }
		content.folderViews[index].scrollOffset = scrollPosition
		commitAction(FolderViewState.Action.alreadyUpdatedScrollPosition(folderUUID))
	}
	
	func toggleEditing(folderUUID: UUID) {
		guard let index = content.folderViews.index(where: { $0.folderUUID == folderUUID }) else { return }
		content.folderViews[index].editing = !content.folderViews[index].editing
		commitAction(FolderViewState.Action.toggleEditing(folderUUID))
	}
	
	func showCreateFolder(parentUUID: UUID) {
		content.textAlert = TextAlertState(text: "", parentUUID: parentUUID, recordingUUID: nil)
		commitAction(SplitViewState.Action.showTextAlert)
	}
	
	func showRecorder(parentUUID: UUID) {
		content.recordView = RecordViewState(recordState: RecordState(), parentUUID: parentUUID)
		commitAction(SplitViewState.Action.showRecordView)
	}
	
	func dismissRecording() {
		content.recordView = nil
		commitAction(SplitViewState.Action.dismissRecordView)
	}
	
	func showSaveRecording(uuid: UUID, parentUUID: UUID) {
		content.textAlert = TextAlertState(text: "", parentUUID: parentUUID, recordingUUID: uuid)
		commitAction(SplitViewState.Action.showTextAlert)
	}
	
	func dismissTextAlert() {
		content.textAlert = nil
		commitAction(SplitViewState.Action.dismissTextAlert)
	}
	
	func updateAlertText(_ text: String) {
		content.textAlert?.text = text
		commitAction(TextAlertState.Action.updateText)
	}
	
	func updatePlayState(_ playState: PlayState) {
		content.playView.playState = playState
		commitAction(PlayViewState.Action.updatePlayState, sideEffect: true)
	}
	
	func updateRecordState(_ recordState: RecordState) {
		content.recordView?.recordState = recordState
		commitAction(RecordViewState.Action.updateRecordState, sideEffect: true)
	}
	
	func togglePlay() {
		guard var playState = content.playView.playState else { return }
		playState.isPlaying = !playState.isPlaying
		content.playView.playState = playState
		commitAction(PlayViewState.Action.togglePlay)
	}
	
	func changePlaybackPosition(_ position: TimeInterval) {
		guard let previousState = content.playView.playState else { return }
		content.playView.playState = PlayState(isPlaying: previousState.isPlaying, progress: position, duration: previousState.duration)
		commitAction(PlayViewState.Action.changePlaybackPosition)
	}
}
