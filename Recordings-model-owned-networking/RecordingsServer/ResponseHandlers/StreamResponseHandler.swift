import Foundation

class StreamResponseHandler: HttpResponseHandler {
	override class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return url.path.hasPrefix("/stream/")
	}
	
	override func receiveConnection(_ connection: HttpConnection) throws {
		connection.setMaximumConnectionDuration(10 * 60)
		try super.receiveConnection(connection)
	}
	
	override func startResponse(connection: HttpConnection) throws {
		DispatchQueue.main.async {
			do {
				let components = self.url.path.components(separatedBy: "/").dropFirst(2)
				guard
					let uuidString = components.first,
					let uuid = UUID(uuidString: uuidString),
					let fileHandle = try? FileHandle(forReadingFrom: Store.shared.fileURL(for: uuid)) else {
					throw HttpStatusCode.notFound
				}
				
				let originalLength = fileHandle.seekToEndOfFile()
				var length = originalLength
				var offset: UInt64 = 0
				var code = HttpStatusCode.ok
				var additionalHeaders: Dictionary<String, String> = ["Accept-Ranges": "bytes"]
				if let rangeHeader = self.headers["Range"], rangeHeader.hasPrefix("bytes=") {
					let components = rangeHeader.dropFirst(6).split(separator: "-")
					if components.count == 2, let start = UInt64(String(components.first!)), var end = UInt64(String(components.last!)) {
						code = HttpStatusCode.partialContent
						if end >= length {
							end = length - 1
						}
						if start > end {
							offset = length
							length = 0
						} else {
							offset = start
							length = end - start + 1
						}
						additionalHeaders["Content-Range"] = "bytes \(offset)-\(offset + length - 1)/\(originalLength)"
					}
				}
				fileHandle.seek(toFileOffset: offset)
				
				let data = fileHandle.readData(ofLength: Int(length))
				self.sendResponse(code: code, mimeType: "audio/mp4", data: data, additionalHeaders: additionalHeaders, connection: connection)
			} catch let error as HttpStatusCode {
				self.sendErrorResponse(code: error, connection: connection)
			} catch {
				self.sendErrorResponse(code: HttpStatusCode.internalServerError, connection: connection)
			}
		}
	}
}
