import Foundation

struct Recording: Codable {
	let uuid: UUID
	let parentUUID: UUID?
	var name: String

	init(name: String, uuid: UUID, parentUUID: UUID?) {
		self.name = name
		self.uuid = uuid
		self.parentUUID = parentUUID
	}
}
