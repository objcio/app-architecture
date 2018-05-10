import Foundation

extension AppState {
	enum Message: Equatable {
		// Navigation
		case back
		case popDetail
		
		case player(PlayerState.Message)
		case recording(RecordState.Message)
		case createNewRecording
		case showCreateFolderPrompt
		case createFolder(String?)
		case selectFolder(Folder)
		case selectRecording(Recording)
		case delete(Item)
		case storeChanged(Folder)
		case recorderAvailable(Recorder?)
		case loaded(Recording, Player?)
		
		static func select(_ item: Item) -> Message {
			switch item {
			case let .folder(folder): return .selectFolder(folder)
			case let .recording(recording): return .selectRecording(recording)
			}
		}
	}
	
	mutating func update(_ msg: Message) -> [Command<Message>] {
		switch msg {
		case .popDetail:
			if playState != nil {
				playState = nil
			}
			return []
		case .back:
			folders.removeLast()
			return []
		case .createNewRecording:
			return [Command.createRecorder(available: { .recorderAvailable($0) })]
		case .recorderAvailable(let recorder):
			guard let recorder = recorder else {
				return [Command.modalAlert(title: "Cannot record", accept: "OK")]
			}
			self.recordState = RecordState(folder: currentFolder, recorder: recorder)
			return []
		case let .selectFolder(folder):
			folders.append(folder)
			return []
		case let .selectRecording(recording):
			return [Command.load(recording: recording, available: { .loaded(recording, $0) })]
		case .delete(let item):
			return [Command.delete(item)]
		case .recording(let recordingMsg):
			let result: [Command<RecordState.Message>]? = recordState?.update(recordingMsg)
			if case .save(_) = recordingMsg {
				recordState = nil
			}
			return result?.map { recordCommand in
				return recordCommand.map(Message.recording)
			} ?? []
		case .player(let msg):
			return playState?.update(msg) ?? []
		case .loaded(let r, let p):
			guard let p = p else {
				return [Command.modalAlert(title: "Cannot play \(r.name)", accept: "OK")]
			}
			playState = PlayerState(recording: r, player: p)
			return []
		case .showCreateFolderPrompt:
			return [Command.modalTextAlert(title: .createFolder,
				accept: .create,
				cancel: .cancel,
				placeholder: .folderName,
				submit: { .createFolder($0) })]
		case .createFolder(let name):
			guard let s = name else { return [] }
			return [Command.createFolder(name: s, parent: currentFolder)]
		case .storeChanged(let root):
			folders = folders.compactMap { root.find($0) }
			if let recording = playState?.recording {
				if let newRecording = root.find(recording) {
					playState?.recording = newRecording
				} else {
					playState = nil
				}
			}
			return []
		}
	}
}

extension AppState {
	var subscriptions: [Subscription<Message>] {
		var subs: [Subscription<Message>] = [
			.storeChanged(handle: { .storeChanged($0) })
		]
		if let r = recordState?.recorder {
			subs.append(.recordProgress(recorder: r, handle: { .recording(.progressChanged($0)) }))
		}
		if let p = playState {
			subs.append(.playProgress(player: p.player, handle: { Message.player(.playPositionChanged($0, isPlaying: $1)) }))
		}
		return subs
	}
}

fileprivate extension String {
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
}
