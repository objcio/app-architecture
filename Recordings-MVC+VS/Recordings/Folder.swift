import Foundation

struct Folder: Codable {
	let uuid: UUID
	let parentUUID: UUID?
	var name: String

	private(set) var childUUIDs: Set<UUID>
	func sortedChildUUIDs(in store: DocumentStore) -> [UUID] {
		return childUUIDs.sorted(by: { (store.content[$0]?.name ?? "") < (store.content[$1]?.name ?? "") })
	}
	
	init(name: String, uuid: UUID, parentUUID: UUID?) {
		self.init(name: name, uuid: uuid, parentUUID: parentUUID, childUUIDs: [])
	}

	init(name: String, uuid: UUID, parentUUID: UUID?, childUUIDs: Set<UUID>) {
		self.name = name
		self.uuid = uuid
		self.parentUUID = parentUUID
		self.childUUIDs = childUUIDs
	}
	
	mutating func addChild(_ childUUID: UUID) {
		childUUIDs.insert(childUUID)
	}
	
	mutating func removeChild(_ uuid: UUID, store: DocumentStore) {
		if let folder = store.content[uuid]?.folder {
			for childUUID in folder.childUUIDs {
				store.removeItem(uuid: childUUID)
			}
		}
		childUUIDs.remove(uuid)
	}
}

fileprivate extension String {
	static let childsKey = "childs"
}
