import Foundation

struct Folder: Codable, Equatable {
	var name: String
	var uuid: UUID
	var items: [Item]
	
	init(name: String, uuid: UUID = UUID(), items: [Item] = []) {
		self.name = name
		self.uuid = uuid
		self.items = items
	}
}

extension Folder {
	func find(_ folder: Folder) -> Folder? {
		guard case let .folder(f)? = find(.folder(folder)) else { return nil }
		return f
	}
	
	func find(_ recording: Recording) -> Recording? {
		guard case let .recording(r)? = find(.recording(recording)) else { return nil }
		return r
	}

	func find(_ item: Item) -> Item? {
		if uuid == item.uuid { return .folder(self) }
		for child in items {
			if child.uuid == item.uuid { return child }
			if case let .folder(folder) = child, let result = folder.find(item) {
				return result
			}
		}
		return nil
	}

	mutating func replace(_ folder: Folder) {
		replace(.folder(folder))
	}
	
	mutating func replace(_ newItem: Item) {
		if case let .folder(newFolder) = newItem, uuid == newFolder.uuid {
			self = newFolder
		} else {
			for (item, index) in zip(items, items.indices) {
				if item.uuid == newItem.uuid {
					items[index] = newItem
				} else if case var .folder(nestedFolder) = item {
					nestedFolder.replace(newItem)
					items[index] = .folder(nestedFolder)
				}
			}
		}
	}

	mutating func add(_ item: Item) {
		items.append(item)
		items.sort(by: { $0.name < $1.name })
	}
	
	mutating func delete(_ item: Item) {
		for (child, index) in zip(items, items.indices) {
			if child.uuid == item.uuid {
				items.remove(at: index)
				return
			}
			if case var .folder(folder) = child {
				folder.delete(item)
				items[index] = .folder(folder)
			}
		}
	}
}
