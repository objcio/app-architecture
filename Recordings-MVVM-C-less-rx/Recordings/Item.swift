import Foundation
import RxDataSources

class Item: IdentifiableType, Hashable, Codable {
	var hashValue: Int { return uuid.hashValue }
	static func ==(lhs: Item, rhs: Item) -> Bool {
		return lhs.uuid == rhs.uuid
	}
	
	var identity: UUID { return uuid }
	
	let uuid: UUID
	private(set) var name: String
	weak var store: Store?
	weak var parent: Folder? {
		didSet {
			store = parent?.store
		}
	}
	
	init(name: String, uuid: UUID) {
		self.name = name
		self.uuid = uuid
		self.store = nil
	}
	
	enum Keys: CodingKey { case name, uuid }

	required init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: Keys.self)
		self.uuid = try c.decode(UUID.self, forKey: .uuid)
		self.name = try c.decode(String.self, forKey: .name)
		self.store = nil
		self.parent = nil
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: Keys.self)
		try c.encode(name, forKey: .name)
		try c.encode(uuid, forKey: .uuid)
	}
	
	func setName(_ newName: String) {
		name = newName
		if let p = parent {
			let (oldIndex, newIndex) = p.reSort(changedItem: self)
			store?.save(self, userInfo: [Item.changeReasonKey: Item.renamed, Item.oldValueKey: oldIndex, Item.newValueKey: newIndex, Item.parentFolderKey: p])
		}
	}
	
	func deleted() {
		parent = nil
	}
	
	var uuidPath: [UUID] {
		var path = parent?.uuidPath ?? []
		path.append(uuid)
		return path
	}
	
	func item(atUUIDPath path: ArraySlice<UUID>) -> Item? {
		guard let first = path.first, first == uuid else { return nil }
		return self
	}
}

fileprivate extension String {
	static let nameKey = "name"
	static let uuidKey = "uuid"
	static let isFolderKey = "isFolder"
}

extension Item {
	static let changeReasonKey = "reason"
	static let newValueKey = "newValue"
	static let oldValueKey = "oldValue"
	static let parentFolderKey = "parentFolder"
	static let renamed = "renamed"
	static let added = "added"
	static let removed = "removed"
}

