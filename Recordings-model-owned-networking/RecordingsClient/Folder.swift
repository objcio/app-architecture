import Foundation

class Folder: Item {
	var contents: [Item] {
		didSet {
			for item in contents {
				item.store = store
				item.parent = self
			}
			contents.sort(by: { $0.name < $1.name })
		}
	}
	override weak var store: Store? {
		didSet {
			contents.forEach { $0.store = store }
		}
	}
	
	override init(name: String, uuid: UUID) {
		contents = []
		super.init(name: name, uuid: uuid)
	}
	
	init?(name: String, uuid: UUID, dict: [String: Any]) {
		self.contents = Folder.load(jsonContents: dict[.contentsKey])
		super.init(name: name, uuid: uuid)
		self.contents.forEach { $0.parent = self }
	}
	
	override func deleted() {
		for item in contents {
			remove(item)
		}
		super.deleted()
	}
	
	func add(_ item: Item) {
		assert(contents.contains { $0 === item } == false)
		contents.append(item)
		let newIndex = contents.index { $0 === item }!
		item.parent = self
		store?.save(item, userInfo: [Item.changeReasonKey: Item.added, Item.newValueKey: newIndex, Item.parentFolderKey: self])
	}
	
	func reSort(changedItem: Item) -> (oldIndex: Int, newIndex: Int) {
		let oldIndex = contents.index { $0 === changedItem }!
		contents.sort(by: { $0.name < $1.name })
		let newIndex = contents.index { $0 === changedItem }!
		return (oldIndex, newIndex)
	}
	
	func remove(_ item: Item) {
		guard let index = contents.index(where: { $0 === item }) else { return }
		item.deleted()
		contents.remove(at: index)
		store?.save(item, userInfo: [Item.changeReasonKey: Item.removed, Item.oldValueKey: index, Item.parentFolderKey: self])
	}

	override func item(atUUIDPath path: ArraySlice<UUID>) -> Item? {
		guard let first = path.first else { return super.item(atUUIDPath: path) }
		return contents.first { $0.uuid == first }.flatMap { $0.item(atUUIDPath: path.dropFirst()) }
	}
	
	override var json: [String: Any] {
		var result = super.json
		result[.contentsKey] = contents.map { $0.json }
		return result
	}
	
	static func load(jsonContents: Any?) -> [Item] {
		return (jsonContents as? Array<Any>)?.compactMap { Item.load(json: $0) } ?? []
	}
}

fileprivate extension String {
	static let contentsKey = "contents"
}

