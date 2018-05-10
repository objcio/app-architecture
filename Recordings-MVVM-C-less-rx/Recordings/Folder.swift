import Foundation

class Folder: Item {
	private(set) var contents: [Item]
	override weak var store: Store? {
		didSet {
			contents.forEach { $0.store = store }
		}
	}
	
	override init(name: String, uuid: UUID) {
		contents = []
		super.init(name: name, uuid: uuid)
	}
	
	enum FolderKeys: CodingKey { case contents, inherited }
	enum FolderOrRecording: CodingKey { case folder, recording }
	
	required init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: FolderKeys.self)
		var items = [Item]()
		var nested = try c.nestedUnkeyedContainer(forKey: .contents)
		while true {
			let wrapper = try nested.nestedContainer(keyedBy: FolderOrRecording.self)
			if let f = try wrapper.decodeIfPresent(Folder.self, forKey: .folder) {
				items.append(f)
			} else if let r = try wrapper.decodeIfPresent(Recording.self, forKey: .recording) {
				items.append(r)
			} else {
				break
			}
		}
		contents = items

		try super.init(from: c.superDecoder(forKey: .inherited))
		for c in contents {
			c.parent = self
		}
	}

	override func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: FolderKeys.self)
		var nested = c.nestedUnkeyedContainer(forKey: .contents)
		for c in contents {
			var wrapper = nested.nestedContainer(keyedBy: FolderOrRecording.self)
			if let f = c as? Folder {
				try wrapper.encode(f, forKey: .folder)
			} else if let r = c as? Recording {
				try wrapper.encode(r, forKey: .recording)
			}
		}
		_ = nested.nestedContainer(keyedBy: FolderOrRecording.self)
		try super.encode(to: c.superEncoder(forKey: .inherited))
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
		contents.sort(by: { $0.name < $1.name })
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
		guard path.count > 1, let first = path.first else { return super.item(atUUIDPath: path) }
		return contents.first { $0.uuid == first }.flatMap { $0.item(atUUIDPath: path.dropFirst()) }
	}
}

fileprivate extension String {
	static let contentsKey = "contents"
}

