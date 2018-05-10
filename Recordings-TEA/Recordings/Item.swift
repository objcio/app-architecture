import Foundation

enum Item: Codable, Equatable {
	case folder(Folder)
	case recording(Recording)
	
	var name: String {
		get {
			switch self {
			case .folder(let f): return f.name
			case .recording(let r): return r.name
			}
		} set {
			switch self {
			case .folder(var f): f.name = newValue; self = .folder(f)
			case .recording(var r): r.name = newValue; self = .recording(r)
			}
		}
	}
	
	var uuid: UUID {
		switch self {
		case .folder(let f): return f.uuid
		case .recording(let r): return r.uuid
		}
	}
	
	enum Keys: CodingKey { case folder, recording }
	
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: Keys.self)
		if let f = try c.decodeIfPresent(Folder.self, forKey: .folder) {
			self = .folder(f)
		} else {
			self = try .recording(c.decode(Recording.self, forKey: .recording))
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: Keys.self)
		switch self {
		case .folder(let f): try c.encode(f, forKey: .folder)
		case .recording(let r): try c.encode(r, forKey: .recording)
		}
	}
}

