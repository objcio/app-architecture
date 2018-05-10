import Foundation

final class DocumentStore: NotifyingStore {
	enum Action {
		case added(parentUUID: UUID, childUUID: UUID, indexInParent: Int)
		case renamed(parentUUID: UUID, childUUID: UUID, oldIndex: Int, newIndex: Int)
		case removed(parentUUID: UUID, childUUID: UUID, oldIndex: Int)
	}
	
	static let shared = DocumentStore(url: DocumentStore.defaultUrlForShared)
	static let shortName = "store"
	static let rootFolderUUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

	let url: URL?
	var placeholder: URL?
	var persistToUrl: URL? { return url }
	private(set) var content: [UUID: Item]

	init(url: URL?) {
		self.url = url
		
		if let u = url,
			let data = try? Data(contentsOf: u),
			let loaded = try? JSONDecoder().decode(DataType.self, from: data)
		{
			content = loaded
			if enableDebugLogging, let string = String(data: data, encoding: .utf8) {
				print("On startup, \(DocumentStore.shortName) is:\n\(string)")
			}
		} else {
			content = [DocumentStore.rootFolderUUID: .folder(Folder(name: "", uuid: DocumentStore.rootFolderUUID, parentUUID: nil))]
			if enableDebugLogging, let jsonData = try? serialized(), let string = String(data: jsonData, encoding: .utf8) {
				print("On startup, \(DocumentStore.shortName) is:\n\(string)")
			}
		}

		for (key, value) in content {
			if let p = value.parentUUID, let contains = content[p]?.folder?.childUUIDs.contains(key), contains {
			} else if key != DocumentStore.rootFolderUUID {
				content.removeValue(forKey: key)
			}
		}
	}
	
	func loadWithoutNotifying(jsonData: Data) {
		do {
			content = try JSONDecoder().decode(DataType.self, from: jsonData)
		} catch {
			print("Failed to load. \(error)")
		}
	}
	
	private func addItem(_ fr: Item) {
		guard let parentUUID = fr.parentUUID, var parentFolder = content[parentUUID]?.folder else { return }
		
		// Add the item to the store
		content[fr.uuid] = fr
		
		// Update the parent to contain the folder
		parentFolder.addChild(fr.uuid)
		let newIndex = parentFolder.sortedChildUUIDs(in: self).index(of: fr.uuid)!
		content.updateValue(.folder(parentFolder), forKey: parentUUID)
		
		// Send the notification
		commitAction(Action.added(parentUUID: parentUUID, childUUID: fr.uuid, indexInParent: newIndex))
	}
	
	func newFolder(named: String, parentUUID: UUID) {
		let folder = Folder(name: named, uuid: UUID(), parentUUID: parentUUID)
		addItem(.folder(folder))
	}
	
	func addRecording(_ r: Recording) {
		addItem(.recording(r))
	}
	
	func renameItem(uuid: UUID, newName: String) {
		guard
			var item = content[uuid],
			let parentUUID = item.parentUUID,
			let parentFolder = content[parentUUID]?.folder,
			parentFolder.childUUIDs.contains(uuid)
		else {
			return
		}
		
		let oldIndex = parentFolder.sortedChildUUIDs(in: self).index(of: item.uuid)!
		item.name = newName
		content.updateValue(item, forKey: uuid)
		let newIndex = parentFolder.sortedChildUUIDs(in: self).index(of: item.uuid)!

		commitAction(Action.renamed(parentUUID: parentUUID, childUUID: uuid, oldIndex: oldIndex, newIndex: newIndex))
	}
	
	func removeItem(uuid: UUID) {
		guard
			let item = content[uuid],
			let parentUUID = item.parentUUID,
			var parentFolder = content[parentUUID]?.folder,
			let oldIndex = parentFolder.sortedChildUUIDs(in: self).index(of: item.uuid)
		else { return }
		
		parentFolder.removeChild(item.uuid, store: self)
		content.removeValue(forKey: item.uuid)
		content.updateValue(.folder(parentFolder), forKey: parentUUID)
		commitAction(Action.removed(parentUUID: parentUUID, childUUID: uuid, oldIndex: oldIndex))
	}
	
	func fileURL(for uuid: UUID) -> URL? {
		return url?.deletingLastPathComponent().appendingPathComponent(uuid.uuidString + ".m4a") ?? placeholder
	}
}
