import Foundation

enum Item: Codable {
	case folder(Folder)
	case recording(Recording)
	
	func getContent<R>(folder: (Folder) -> R, recording: (Recording) -> R) -> R {
		switch self {
		case .folder(let f): return folder(f)
		case .recording(let r): return recording(r)
		}
	}
	
	var name: String {
		get { return getContent(folder: { $0.name }, recording: { $0.name }) }
		set {
			switch self {
			case .folder(let f):
				self = Item(Folder(name: newValue, uuid: f.uuid, parentUuid: f.parentUuid, childUuids: f.childUuids))
			case .recording(let r):
				self = Item(Recording(name: newValue, uuid: r.uuid, parentUuid: r.parentUuid))
			}
		}
	}
	var parentUuid: UUID? { return getContent(folder: { $0.parentUuid }, recording: { $0.parentUuid }) }
	var uuid: UUID { return getContent(folder: { $0.uuid }, recording: { $0.uuid }) }
	var isFolder: Bool { return folder != nil }
	
	var folder: Folder? { return getContent(folder: { $0 }, recording: { _ in nil }) }
	var recording: Recording? { return getContent(folder: { _ in nil }, recording: { $0 }) }
	
	init(_ recording: Recording) { self = .recording(recording) }
	init(_ folder: Folder) { self = .folder(folder) }

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

struct Recording: Codable {
	var name: String
	let uuid: UUID
	let parentUuid: UUID?
}

struct Folder: Codable {
	var name: String
	let uuid: UUID
	let parentUuid: UUID?
	var childUuids: Set<UUID>
}
