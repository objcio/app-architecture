import Foundation

struct Recording: Codable, Equatable {
	var name: String
	var uuid: UUID
	
	init(name: String, uuid: UUID) {
		self.name = name
		self.uuid = uuid
	}
}

