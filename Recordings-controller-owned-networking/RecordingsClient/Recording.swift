import Foundation

struct Recording {
	var name: String
	var uuidPath: [UUID]
	var uuid: UUID {
		return uuidPath.last!
	}
}

extension Recording {
	init?(uuidPath: [UUID], json: Any) {
		guard let dict = json as? [String:Any],
		let name = dict[.nameKey] as? String,
		let uuidString = dict[.uuidKey] as? String,
		let uuid = UUID(uuidString: uuidString)
			else { return nil }
		self.name = name
		self.uuidPath = uuidPath + [uuid]
	}

	var json: [String:Any] {
		return [
			.nameKey: name,
			.isFolderKey: false,
			.uuidKey: uuid.uuidString
		]
	}
}
