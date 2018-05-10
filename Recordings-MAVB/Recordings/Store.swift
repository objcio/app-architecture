import Foundation

final class Store: Codable {
	enum Notification {
		case mutation(SetMutation<Item>)
		case temporary(TempFile?)
		case reload
		case noEffect
	}
	
	struct TempFile: Codable {
		let uuid: UUID
		let parentUuid: UUID
		let url: URL
		var isRecorded: Bool
	}
	
	static let rootFolderUuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
	static func url(relativeComponent: String) -> URL {
		return try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(relativeComponent)
	}
	
	let path: String?
	var placeholder: URL?
	var content: [UUID: Item]
	var temporary: TempFile?
	
	init(relativePath: String? = .storeLocation, items: [Item]? = nil) {
		self.path = relativePath
		self.placeholder = nil
		if let c = items {
			content = Dictionary(uniqueKeysWithValues: c.map { ($0.uuid, $0) })
		} else if let component = path,
			let jsonData = try? Data(contentsOf: Store.url(relativeComponent: component)),
			let dictionary = try? JSONDecoder().decode([UUID: Item].self, from: jsonData) {
			content = dictionary
		} else {
			content = [Store.rootFolderUuid: Item(Folder(name: .recordings, uuid: Store.rootFolderUuid, parentUuid: nil, childUuids: []))]
		}
	}
	
	func deleteTemporary() -> Notification {
		guard let existing = temporary else { return .noEffect }
		removeFile(for: existing.uuid)
		return Notification.temporary(nil)
	}
	
	func recordingComplete() -> Notification {
		temporary?.isRecorded = true
		return temporary.map { Notification.temporary($0) } ?? .noEffect
	}
	
	func createTemporary(parentUuid: UUID) -> Notification {
		_ = deleteTemporary()
		let uuid = UUID()
		temporary = TempFile(uuid: uuid, parentUuid: parentUuid, url: fileURL(for: uuid), isRecorded: false)
		return Notification.temporary(temporary)
	}
	
	func update(_ item: Item, remove: Bool, parent: Folder?, notification: Notification) -> Notification {
		if remove {
			content.removeValue(forKey: item.uuid)
		} else {
			content[item.uuid] = item
		}
		if let p = parent {
			content.updateValue(Item(p), forKey: p.uuid)
		}
		save()
		return notification
	}
	
	func newFolder(named: String, parentUuid: UUID) -> Notification {
		guard var parent = content[parentUuid]?.folder else { return .noEffect }
		let folder = Folder(name: named, uuid: UUID(), parentUuid: parentUuid, childUuids: [])
		parent.childUuids.insert(folder.uuid)
		return update(Item(folder), remove: false, parent: parent, notification: .mutation(.insert([Item(folder)])))
	}
	
	func addRecording(_ r: Recording) -> Notification {
		guard let parentUuid = r.parentUuid, var parent = content[parentUuid]?.folder else { return .noEffect }
		parent.childUuids.insert(r.uuid)
		return update(Item(r), remove: false, parent: parent, notification: .mutation(.insert([Item(r)])))
	}
	
	func renameItem(uuid: UUID, newName: String) -> Notification {
		guard var item = content[uuid] else { return .noEffect }
		item.name = newName
		return update(item, remove: false, parent: nil, notification: .mutation(.update([item])))
	}
	
	func removeItem(uuid: UUID) -> Notification {
		guard let item = content[uuid], let parentUuid = item.parentUuid, var parentFolder = content[parentUuid]?.folder else { return .noEffect }
		parentFolder.childUuids.remove(item.uuid)
		removeFile(for: item.uuid)
		return update(item, remove: true, parent: parentFolder, notification: .mutation(.delete([item])))
	}
	
	@discardableResult func save() -> Notification {
		do {
			if let component = path {
				let data = try JSONEncoder().encode(content)
				try data.write(to: Store.url(relativeComponent: component))
			}
		} catch {
			assertionFailure("Error: \(error)")
		}
		return .noEffect
	}
	
	func removeFile(for uuid: UUID) {
		let url = fileURL(for: uuid)
		if url != placeholder {
			_ = try? FileManager.default.removeItem(at: url)
		}
	}
	
	func fileURL(for uuid: UUID) -> URL {
		guard let component = path else { return placeholder ?? URL(fileURLWithPath: "") }
		return Store.url(relativeComponent: component).deletingLastPathComponent().appendingPathComponent(uuid.uuidString + ".m4a")
	}
}

fileprivate extension String {
	static let recordings = NSLocalizedString("Recordings", comment: "")
	static let rootItemKey = "rootItem"
	static let storeLocation = "store.json"
}
