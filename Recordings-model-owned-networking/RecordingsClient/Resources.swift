import Foundation

extension Folder {
	var contentsResource: Resource<[Item]> {
		let url = URL(string: "\(store!.serverURL)/contents/\(uuidPath.map { $0.uuidString }.joined(separator: "/"))")!
		return Resource(url: url, parseElementJSON: Item.load)
	}

	@discardableResult
	func loadContents(completion: @escaping () -> ()) -> URLSessionTask? {
		let task = URLSession.shared.load(contentsResource) { [weak self] result in
			completion()
			guard case let .success(items) = result else { return }
			self?.updateContents(from: items)
		}
		return task
	}
}

extension Folder {
	func updateContents(from items: [Item]) {
		// Preserve pending items
		let oldContents = self.contents.filter { $0.nextChange != nil }
		
		// Get only those new items not affected by pending changes
		let newContents = items.filter { new in oldContents.first { $0.uuid == new.uuid } == nil }
		
		// Re-apply old contents to new folders
		for item in newContents {
			guard let folder = item as? Folder, let old = contents.first(where: { item.uuid == $0.uuid }) as? Folder else { continue }
			folder.contents = old.contents
		}
		
		// Apply these old and new contents
		let merged = newContents + oldContents
		contents = merged
		store?.save(self, userInfo: [Item.changeReasonKey: Item.reloaded])
	}
}
