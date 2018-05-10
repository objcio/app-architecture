import Foundation

class UuidResponseHandler: HttpResponseHandler {
	override class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return url.path == "/uuid"
	}
	override func startResponse(connection: HttpConnection) throws {
		// Since the `Store` is accessed from the `main` thread, we need to transfer from the to access the store.
		DispatchQueue.main.async {
			do {
				let uuidString = Store.shared.rootFolder.uuid.uuidString
				let jsonData = try JSONSerialization.data(withJSONObject: ["uuid": uuidString], options: [])
				self.sendResponse(code: .ok, mimeType: "application/json", data: jsonData, connection: connection)
			} catch {
				self.sendErrorResponse(code: HttpStatusCode.internalServerError, connection: connection)
			}
		}
	}
}

