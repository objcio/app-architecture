import UIKit


extension Command {
	static func load(recording: Recording, available: @escaping (Player?) -> Message) -> Command {
		return Command { context in
			let url = Store.shared.fileURL(for: recording)
			let player = Player(url: url)
			context.send(available(player))
		}
	}
	
	static func togglePlay(_ player: Player) -> Command {
		return Command { _ in
			player.togglePlay()
		}
	}
	
	static func seek(_ player: Player, to position: TimeInterval) -> Command {
		return Command { _ in
			player.setProgress(position)
		}
	}
	
	static func saveRecording(name: String, folder: Folder, url: URL) -> Command {
		return Command { _ in
			let recording = Recording(name: name, uuid: UUID())
			let destination = Store.shared.fileURL(for: recording)
			try! FileManager.default.copyItem(at: url, to: destination)
			Store.shared.add(.recording(recording), to: folder)
		}
	}
	
	static func stopRecorder(_ recorder: Recorder) -> Command {
		return Command { _ in
			recorder.stop()
		}
	}
	
	static func delete(_ item: Item) -> Command {
		return Command { _ in
			Store.shared.delete(item)
		}
	}
	
	static func createFolder(name: String, parent: Folder) -> Command {
		return Command { _ in
			let newFolder = Folder(name: name, uuid: UUID())
			Store.shared.add(.folder(newFolder), to: parent)
		}
	}
	
	static func createRecorder(available: @escaping (Recorder?) -> Message) -> Command {
		return Command { context in
			context.send(available(Recorder(url: Store.shared.tempURL())))
		}
	}
	
	static func changeName(of recording: Recording, to name: String) -> Command<Message> {
		return Command { _ in
			Store.shared.changeName(.recording(recording), to: name)
		}
	}
}
