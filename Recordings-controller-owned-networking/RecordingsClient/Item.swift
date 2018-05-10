import Foundation

enum Item {
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
	
	var uuidPath: [UUID] {
		switch self {
		case .folder(let f): return f.uuidPath
		case .recording(let r): return r.uuidPath
		}
	}
	
	var json: [String: Any] {
		switch self {
		case .folder(let f): return f.json
		case .recording(let r): return r.json
		}
	}
	
	var folder: Folder? {
		guard case .folder(let f) = self else { return nil }
		return f
	}
	
	var recording: Recording? {
		guard case .recording(let r) = self else { return nil }
		return r
	}
}
