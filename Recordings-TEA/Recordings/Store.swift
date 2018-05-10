import Foundation

final class Store {
	let baseURL: URL
	var storeURL: URL {
		return baseURL.appendingPathComponent(.storeLocation)
	}
	private(set) var rootFolder: Folder {
		didSet {
			let data = try! JSONEncoder().encode(rootFolder)
			try? data.write(to: storeURL)
			NotificationCenter.default.post(name: Store.changedNotification, object: rootFolder, userInfo: [:])
		}
	}
	
	static let changedNotification = Notification.Name("StoreChanged")
	static let shared = Store(url: try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
	
	init(url: URL) {
		self.baseURL = url
		if let data = try? Data(contentsOf: baseURL.appendingPathComponent(.storeLocation)),
			let folder = try? JSONDecoder().decode(Folder.self, from: data)
		{
			self.rootFolder = folder
		} else {
			self.rootFolder = Folder(name: .recordings, uuid: UUID(), items: [])
		}
	}
	
	func tempURL() -> URL {
		let randomFileName = UUID().uuidString + ".m4a"
		return URL(fileURLWithPath: NSTemporaryDirectory().appending(randomFileName))
	}
	
	func fileURL(for recording: Recording) -> URL {
		return baseURL.appendingPathComponent(recording.uuid.uuidString + ".m4a")
	}
	
	func add(_ item: Item, to folder: Folder) {
		var copy = folder
		copy.add(item)
		rootFolder.replace(copy)
	}
	
	func delete(_ item: Item) {
		rootFolder.delete(item) // todo delete all nested recordings as well
		if case let .recording(recording) = item {
			try? FileManager.default.removeItem(at: fileURL(for: recording))
		}
	}
	
	func changeName(_ item: Item, to newName: String) {
		var copy = item
		copy.name = newName
		rootFolder.replace(copy)
	}
}

fileprivate extension String {
	static let nameKey = "name"
	static let uuidKey = "uuid"
	static let childrenKey = "children"
	static let isFolderKey = "isFolder"
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
	static let storeLocation = "store.json"
}
