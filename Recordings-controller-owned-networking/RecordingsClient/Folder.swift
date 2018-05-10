import Foundation

struct Folder {
	enum State {
		case unloaded
		case loaded
		case loading
	}

	var name: String
	var uuidPath: [UUID]
	var contents: [Item]
	var state: State
	var uuid: UUID { return uuidPath.last! }
}

extension Folder {
	func parseContents(json: Any) -> [Item]? {
		guard let contentsArr = json as? [[String:Any]] else { return nil }
		return contentsArr.compactMap { dict in
			if (dict[.isFolderKey] as? Bool) == true {
				return Folder(parentPath: self.uuidPath, json: dict).map(Item.folder)
			} else {
				return Recording(uuidPath: self.uuidPath, json: dict).map(Item.recording)
			}
		}
	}

	init?(parentPath: [UUID], json: Any) {
		guard let dict = json as? [String:Any],
			(dict[.isFolderKey] as? Bool) == true,
		   let name = dict[.nameKey] as? String,
		   let uuidString = dict[.uuidKey] as? String,
			let uuid = UUID(uuidString: uuidString)
		else { return nil }
		self.name = name
		self.uuidPath = parentPath + [uuid]
		self.contents = []
		self.state = .unloaded
		if let contentsJSON = dict[.contentsKey], let contents = self.parseContents(json: contentsJSON) {
			self.contents = contents
			self.state = .loaded
		}
	}

	var json: [String:Any] {
		return [
			.nameKey: name,
			.isFolderKey: true,
			.uuidKey: uuid.uuidString
		]
	}
}

fileprivate extension String {
	static let contentsKey = "contents"
}

extension String {
	static let nameKey = "name"
	static let uuidKey = "uuid"
	static let isFolderKey = "isFolder"
}
