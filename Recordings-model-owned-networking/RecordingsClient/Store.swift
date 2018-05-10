import Foundation

private let rootUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
private let port = 47328

final class Store {
	static let changedNotification = Notification.Name("StoreChanged")
	static private let documentDirectory = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	static let shared = Store(url: documentDirectory)

	var rootFolder: Folder!
	let localBaseURL: URL
	private var webservice: Webservice!
	
	var serverURL: URL {
		return webservice.remoteURL
	}
	
	init(url: URL) {
		self.localBaseURL = url
		self.webservice = Webservice(store: self, remoteURL: URL(string: "http://localhost:\(port)")!)
		self.webservice.processChanges()
		self.rootFolder = readRootFolder() ?? Folder(name: "", uuid: rootUUID)
		self.rootFolder.store = self
	}
	
	func readRootFolder() -> Folder? {
		guard let data = try? Data(contentsOf: localBaseURL.appendingPathComponent(.storeLocation)),
			let json = try? JSONSerialization.jsonObject(with: data, options: []),
			let folder = Item.load(json: json) as? Folder
			else { return nil }
		return folder
	}
	
	func nextChange(for item: Item) -> Change? {
		return webservice.nextChange(for: item)
	}

	func latestChange(for item: Item) -> Change? {
		return webservice.latestChange(for: item)
	}

	func fileURL(for recording: Recording) -> URL {
		return localBaseURL.appendingPathComponent(recording.uuid.uuidString + ".m4a")
	}
	
	func save(_ item: Item, userInfo: [AnyHashable: Any]) {
		let json = rootFolder.json
		let data = try! JSONSerialization.data(withJSONObject: json, options: [])
		try! data.write(to: localBaseURL.appendingPathComponent(.storeLocation))
		NotificationCenter.default.post(name: Store.changedNotification, object: item, userInfo: userInfo)
	}
	
	func item(atUUIDPath path: [UUID]) -> Item? {
		guard let first = path.first, first == rootFolder.uuid else { return nil }
		return rootFolder.item(atUUIDPath: path.dropFirst())
	}
}

fileprivate extension String {
	static let storeLocation = "store.json"
}
