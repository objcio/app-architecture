import Foundation

class Recording: Item {
	override init(name: String, uuid: UUID) {
		super.init(name: name, uuid: uuid)
	}
	
	var fileURL: URL? {
		return store?.fileURL(for: self)
	}
	override func deleted() {
		store?.removeFile(for: self)
		super.deleted()
	}

	enum RecordingKeys: CodingKey { case inherited }
	
	required init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: RecordingKeys.self)
		try super.init(from: c.superDecoder(forKey: .inherited))
	}

	override func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: RecordingKeys.self)
		try super.encode(to: c.superEncoder(forKey: .inherited))
	}
}

