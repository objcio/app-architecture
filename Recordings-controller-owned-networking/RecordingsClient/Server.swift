import Foundation

struct Server {
	let hostName: String
	let port: Int
	let rootFolder: Folder
	
	init(hostName: String, port: Int, uuid: UUID) {
		self.hostName = hostName
		self.port = port
		self.rootFolder = Folder(name: "", uuidPath: [uuid], contents: [], state: .unloaded)
	}
	
	func streamUrl(for uuid: UUID) -> URL {
		return URL(string: "http://\(self.hostName):\(self.port)/stream/\(uuid.uuidString)")!
	}
}

extension Server {
	var baseUrl: URL {
		return URL(string: "http://\(hostName):\(port)")!
	}
	
	func upload(name: String, folder: Folder, file: TempFile) -> Resource<Recording> {
		let url = baseUrl.appendingPathComponent("/change/create/\(folder.uuidPath.map { $0.uuidString }.joined(separator: "/"))")
		let uuid = UUID()
		let json: [String:Any] = [
			.nameKey: name,
			.uuidKey: uuid.uuidString,
			.isFolderKey: false,
			.fileDataKey: file.data.base64EncodedString()
		]
		
		return Resource(url: url, postJSON: json, parse: checkForError({ response -> Result<Recording> in
			return .success(Recording(name: name, uuidPath: folder.uuidPath + [uuid]))
		}))
	}
	
	func create(folderNamed name: String, in parent: Folder?) -> Resource<Folder> {
		let parentPath = parent?.uuidPath ?? []
		let uuidPath = parentPath.map { $0.uuidString }.joined(separator: "/")
		let url = baseUrl.appendingPathComponent("/change/create/\(uuidPath)")
		let uuid = UUID()
		let json: [String:Any] = [
			.nameKey: name,
			.uuidKey: uuid.uuidString,
			.isFolderKey: true
		]
		return Resource(url: url, postJSON: json, parse: checkForError { result -> Result<Folder> in
			return Result<Folder>.success(Folder(name: name, uuidPath: parentPath + [uuid], contents: [], state: .loaded))
		})
	}
	
	enum ChangeType: String {
		case update
		case delete
	}
	
	func change(_ type: ChangeType, item: Item) -> Resource<()> {
		let parentPath = item.uuidPath.dropLast().map { $0.uuidString }.joined(separator: "/")
		let url = baseUrl.appendingPathComponent("/change/\(type.rawValue)/\(parentPath)")
		return Resource(url: url, postJSON: item.json, parse: checkForError {
			_ in
			()
		})
	}
	
	func contents(of folder: Folder) -> Resource<[Item]> {
		let url = baseUrl.appendingPathComponent("/contents/\(folder.uuidPath.map { $0.uuidString }.joined(separator: "/"))")
		return Resource(url: url, parseJSON: { folder.parseContents(json: $0) })
	}
	
}

fileprivate extension String {
	static let fileDataKey = "fileDataKey"
	static let errorKey = "errorKey"
	static let successKey = "successKey"
}

enum ChangeError: String, Error {
	case itemAlreadyExists = "itemAlreadyExists"
	case fileDataMissing = "fileDataMissing"
	case itemNotFound = "itemNotFound"
	case malformedChangeObject = "malformedChangeObject"
	case parentNotFound = "parentNotFound"
}

enum ChangeOperationError: Error {
	case itemPropertiesMissing
	case unableToParseResponse
	case unknownError(String)
}


func checkForError<A>(_ transform: @escaping ([String:String]) -> A?) -> (Any) -> Result<A> {
	return checkForError { transform($0).map(Result.success) ?? Result.error(ChangeOperationError.unableToParseResponse) }
}

func checkForError<A>(_ transform: @escaping ([String:String]) -> Result<A>) -> (Any) -> Result<A> {
	return { response in
		guard let json = response as? [String:String] else { return .error(ChangeOperationError.unableToParseResponse) }
		if let e = json[.errorKey] {
			return .error(ChangeError(rawValue: e) ?? ChangeOperationError.unknownError(e))
		} else if json[.successKey] == nil {
			return .error(ChangeOperationError.unableToParseResponse)
		} else {
			return transform(json)
		}
		
	}
}
