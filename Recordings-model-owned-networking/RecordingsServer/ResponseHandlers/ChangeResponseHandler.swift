import Foundation

class ChangeResponseHandler: HttpResponseHandler {
	override class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return method == "POST" && url.path.hasPrefix("/change/")
	}
	
	override var maximumContentLength: Int {
		// Limit POST data to 128 MB (which is about 6 hours of Base64 encoded 32kbps mono audio)
		return 128 * 1024 * 1024
	}
	
	override func startResponse(connection: HttpConnection) throws {
		DispatchQueue.main.async {
			do {
				let components = self.url.path.components(separatedBy: "/")
				guard
					let verbString = components.prefix(3).last,
					let verb = ChangeVerb(verbString) else {
					throw HttpStatusCode.notFound
				}

				guard let json = try JSONSerialization.jsonObject(with: self.receivedData, options: []) as? Dictionary<String, Any> else {
					throw HttpStatusCode.internalServerError
				}
				
                if let parentFolder = Store.shared.item(atUUIDPath: components.dropFirst(3).compactMap { UUID(uuidString: $0) }) as? Folder {
					if let item = Item.load(json: json) {
						switch verb {
						case .create:
							if parentFolder.item(atUUIDPath: [item.uuid]) != nil {
								throw ChangeError.itemAlreadyExists
							} else if let folder = item as? Folder {
								parentFolder.add(folder)
							} else if let base64String = json[.fileDataKey] as? String, let fileData = Data(base64Encoded: base64String), let fileURL = parentFolder.store?.fileURL(for: item.uuid) {
								try fileData.write(to: fileURL)
								parentFolder.add(item)
							} else {
								throw ChangeError.fileDataMissing
							}
						case .update:
							if let existing = parentFolder.item(atUUIDPath: [item.uuid]) {
								existing.setName(item.name)
							} else {
								throw ChangeError.itemNotFound
							}
						case .delete:
							if let existing = parentFolder.item(atUUIDPath: [item.uuid]) {
								parentFolder.remove(existing)
							} else {
								throw ChangeError.itemNotFound
							}
						}
					} else {
						throw ChangeError.malformedChangeObject
					}
				} else {
					throw ChangeError.parentNotFound
				}
				let response: Dictionary<String, String> = [.successKey: ""]
				let jsonData = try! JSONSerialization.data(withJSONObject: response, options: [])
				self.sendResponse(code: .ok, mimeType: "application/json", data: jsonData, connection: connection)
			} catch let error as ChangeError {
				let response: Dictionary<String, String> = [.errorKey: error.rawValue]
				let jsonData = try! JSONSerialization.data(withJSONObject: response, options: [])
				self.sendResponse(code: .ok, mimeType: "application/json", data: jsonData, connection: connection)
			} catch let error as HttpStatusCode {
				self.sendErrorResponse(code: error, connection: connection)
			} catch {
				self.sendErrorResponse(code: HttpStatusCode.internalServerError, connection: connection)
			}
		}
	}
}

enum ChangeVerb {
	case create, update, delete
	init?(_ string: String) {
		switch string {
		case "create": self = .create
		case "update": self = .update
		case "delete": self = .delete
		default: return nil
		}
	}
}

enum ChangeError: String, Error {
	case itemAlreadyExists = "itemAlreadyExists"
	case fileDataMissing = "fileDataMissing"
	case itemNotFound = "itemNotFound"
	case malformedChangeObject = "malformedChangeObject"
	case parentNotFound = "parentNotFound"
}

extension String {
	static let fileDataKey = "fileDataKey"
	static let errorKey = "errorKey"
	static let successKey = "successKey"
}

