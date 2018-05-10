import Foundation

class LoggingDelegate: NSObject, StreamDelegate {
	func stream(_ stream: Stream, handle eventCode: Stream.Event) {
		switch eventCode {
		case .errorOccurred:
			print("Error: \(stream.streamError?.localizedDescription ?? "no error")")
		case.endEncountered:
			print("end encountered")
		case .hasBytesAvailable:
			print("has bytes available")
		case Stream.Event.hasSpaceAvailable:
			print("space available")
		case Stream.Event.openCompleted:
			print("open completed")
		default:
			()
		}
		print(eventCode)
	}
}

extension OutputStream {
	func write(_ data: Data) -> Int {
		return data.withUnsafeBytes {
			self.write($0, maxLength: data.count)
		}
	}

	// Write using the TCP over JSON protocol:
	// - first a 206 byte
	// - then an UInt32 with the length (encoded as 4 bytes)
	// - then the JSON data
	func writeJSON(object: Any) throws {
		let data = try JSONSerialization.data(withJSONObject: object, options: [])
		writeJSONData(data)
	}

	func writeJSONData(_ data: Data) {
		write([206], maxLength: 1)
		let num = data.count
		var encodedLength = Data(count: 4)
		encodedLength.withUnsafeMutableBytes { $0.pointee = Int32(num) }
		_ = write(encodedLength)
		_ = write(data)

	}
}

class RemoteDebugger: NSObject, NetServiceBrowserDelegate {
	let browser = NetServiceBrowser()
	var connections: [NetService] = []
	override init() {
		super.init()
		browser.delegate = self
		browser.searchForServices(ofType: "_debug._tcp", inDomain: "local")
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
		print("did not search: \(errorDict)")
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		connections.append(service)
	}

	func write(jsonData data: Data) {
		for service in connections {
			var i: InputStream? = nil
			var o: OutputStream? = nil
			service.getInputStream(&i, outputStream: &o)
			guard let out = o else { return }
			out.open()
			out.writeJSONData(data)
			defer { out.close() }
		}
	}
}
