import Foundation

struct SplitViewState: Codable {
	enum Action {
		case pushFolderView
		case popFolderView
		case alreadyPoppedFolderView
		case changedPlaySelection
		case alreadyDismissedDetailView
		case showRecordView
		case dismissRecordView
		case showTextAlert
		case dismissTextAlert
	}
	
	var folderViews: [FolderViewState]
	var playView: PlayViewState
	var recordView: RecordViewState?
	var textAlert: TextAlertState?
	
	init(folderViews: [FolderViewState] = [FolderViewState(uuid: DocumentStore.rootFolderUUID)], playView: PlayViewState = PlayViewState(uuid: nil), recordView: RecordViewState? = nil, textAlert: TextAlertState? = nil) {
		self.folderViews = folderViews
		self.playView = playView
		self.recordView = recordView
		self.textAlert = textAlert
	}
}

struct FolderViewState: Codable {
	enum Action {
		case toggleEditing(UUID)
		case alreadyUpdatedScrollPosition(UUID)
	}
	
	let folderUUID: UUID
	var editing: Bool
	var scrollOffset: Double
	init(uuid: UUID, editing: Bool = false, scrollOffset: Double = 0) {
		self.folderUUID = uuid
		self.editing = editing
		self.scrollOffset = scrollOffset
	}
}

struct RecordViewState: Codable {
	enum Action {
		case updateRecordState
	}
	var recordState: RecordState
	let parentUUID: UUID
	
	init(recordState: RecordState, parentUUID: UUID) {
		self.recordState = recordState
		self.parentUUID = parentUUID
	}
}

struct PlayViewState: Codable {
	enum Action {
		case updatePlayState
		case togglePlay
		case changePlaybackPosition
	}
	
	let uuid: UUID?
	var playState: PlayState?
	
	init(uuid: UUID?, playState: PlayState? = nil) {
		self.uuid = uuid
		self.playState = nil
	}
}

struct TextAlertState: Codable {
	enum Action {
		case updateText
	}
	var text: String
	let parentUUID: UUID
	let recordingUUID: UUID?

	init(text: String, parentUUID: UUID, recordingUUID: UUID? ) {
		self.text = text
		self.parentUUID = parentUUID
		self.recordingUUID = recordingUUID
	}
}

