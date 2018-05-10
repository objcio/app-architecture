import Foundation

final class Webservice {
	private var processing = false
	private weak var store: Store!
	let remoteURL: URL
	private var pendingItems: [PendingItem] = [] {
		didSet { saveQueue() }
	}

	static private let documentDirectory = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	static private let queueURL = Webservice.documentDirectory.appendingPathComponent("queue.json")

	init(store: Store, remoteURL: URL) {
		self.store = store
		self.remoteURL = remoteURL
		loadQueue()
		
		NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange(_:)), name: Store.changedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
	}
	
	func latestChange(for item: Item) -> Change? {
		return pendingItems.reversed().first { $0.uuidPath == item.uuidPath }?.change
	}

	func nextChange(for item: Item) -> Change? {
		return pendingItems.first { $0.uuidPath == item.uuidPath }?.change
	}
	
	@objc func storeDidChange(_ note: Notification) {
		guard let pending = PendingItem(note) else { return }
		pendingItems.append(pending)
		processChanges()
	}
	
	@objc func didBecomeActive() {
		processChanges()
	}

	private func loadQueue() {
		guard let data = try? Data(contentsOf: Webservice.queueURL) else { return }
		pendingItems = try! JSONDecoder().decode([PendingItem].self, from: data)
	}
	
	private func saveQueue() {
		try! JSONEncoder().encode(pendingItems).write(to: Webservice.queueURL)
	}
	
	func processChanges() {
		guard !processing, let pending = pendingItems.first else { return }
		processing = true

		let resource = pending.resource(remoteURL: remoteURL, localBaseURL: store.localBaseURL)
		URLSession.shared.load(resource) { [weak self] result in
			guard let s = self else { return }
			if case let .error(e) = result {
				if let changeError = e as? ChangeError {
					switch changeError {
					case .fileDataMissing, .itemNotFound, .malformedChangeObject, .parentNotFound, .invalidResponse, .unknown:
						s.store.item(atUUIDPath: pending.uuidPath)?.remove()
					case .itemAlreadyExists:
						// Created item already exists on server. Ignore.
						break
					}
					s.pendingItems.removeFirst()
				} else {
					// Network error. Keep pending change in queue to retry.
				}
			} else {
				s.pendingItems.removeFirst()
				if let item = s.store.item(atUUIDPath: pending.uuidPath), let parent = item.parent, let index = parent.contents.index(where: { $0 === item }) {
					NotificationCenter.default.post(name: Store.changedNotification, object: item, userInfo: [
						Item.changeReasonKey: Item.reloaded,
						Item.oldValueKey: index,
						Item.newValueKey: index,
						Item.parentFolderKey: parent
					])
				}
			}
			s.processing = false
			s.processChanges()
		}
	}
}


enum Change: String, Codable {
	case create = "create"
	case update = "update"
	case delete = "delete"
}

extension Change {
	fileprivate init?(changeReason: String) {
		switch changeReason {
		case Item.added: self = .create
		case Item.removed: self = .delete
		case Item.renamed: self = .update
		case Item.reloaded: return nil
		default: fatalError()
		}
	}
}

private struct PendingItem: Codable {
	var change: Change
	var uuidPath: [UUID]
	var name: String
	var isFolder: Bool
	var recordingURL: URL?
}

extension PendingItem {
	init?(_ note: Notification) {
		guard
			let changeReason = note.userInfo?[Item.changeReasonKey] as? String,
			let change = Change(changeReason: changeReason)
			else { return nil }
		guard
			let item = note.object.flatMap({ $0 as? Item }),
			let parent = note.userInfo?[Item.parentFolderKey] as? Item
			else { fatalError() }
		self.init(change: change, item: item, parent: parent)
	}
	
	init(change: Change, item: Item, parent: Item) {
		let uuidPath = parent.uuidPath + [item.uuid]
		self.init(change: change, uuidPath: uuidPath, name: item.name, isFolder: item is Folder, recordingURL: (item as? Recording)?.fileURL)
	}
	
	func json(localBaseURL: URL) -> [String: Any] {
		var result: [String: Any] = [
			"name": name,
			"uuid": uuidPath.last!.uuidString,
			"isFolder": isFolder
		]
		if change == .create, let url = recordingURL {
			// We re-create the URL because it changes between app launches on the simulator
			let newURL = localBaseURL.appendingPathComponent(url.lastPathComponent)
			result["fileDataKey"] = try! Data(contentsOf: newURL).base64EncodedString()
		}
		return result
	}
	
	func resource(remoteURL: URL, localBaseURL: URL) -> Resource<()> {
		let parentUUIDPath = uuidPath.dropLast()
		let url = URL(string: "\(remoteURL)/change/\(change.rawValue)/\(parentUUIDPath.map { $0.uuidString }.joined(separator: "/"))")!
		return Resource(url: url, postJSON: json(localBaseURL: localBaseURL)) { json -> Result<()> in
			guard let response = json as? Dictionary<String, String> else { return .error(ChangeError.invalidResponse) }
			if let e = response[.errorKey] {
				return .error(ChangeError(rawValue: e) ?? ChangeError.unknown)
			} else {
				return .success(())
			}
		}
	}
}

enum ChangeError: String, Error {
	case itemAlreadyExists = "itemAlreadyExists"
	case fileDataMissing = "fileDataMissing"
	case itemNotFound = "itemNotFound"
	case malformedChangeObject = "malformedChangeObject"
	case parentNotFound = "parentNotFound"
	case invalidResponse = "invalidResponse"
	case unknown = "unknown"
}

fileprivate extension String {
	static let fileDataKey = "fileDataKey"
	static let errorKey = "errorKey"
}
