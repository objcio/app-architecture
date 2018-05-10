import Foundation

class ContentsResponseHandler: HttpResponseHandler {
	override class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return url.path.hasPrefix("/contents/")
	}
	override func startResponse(connection: HttpConnection) throws {
		DispatchQueue.main.async {
			do {
				let components = self.url.path.components(separatedBy: "/").dropFirst(2)
				guard let folder = Store.shared.item(atUUIDPath: components.compactMap { UUID(uuidString: $0) }) as? Folder else {
					throw HttpStatusCode.notFound
				}
				let jsonData = try JSONSerialization.data(withJSONObject: folder.jsonContentsNoFollow, options: [])
				self.sendResponse(code: .ok, mimeType: "application/json", data: jsonData, connection: connection)
			} catch let error as HttpStatusCode {
				self.sendErrorResponse(code: error, connection: connection)
			} catch {
				self.sendErrorResponse(code: HttpStatusCode.internalServerError, connection: connection)
			}
		}
	}
}
