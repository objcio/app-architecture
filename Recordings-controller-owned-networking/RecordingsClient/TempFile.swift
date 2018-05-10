import Foundation

final class TempFile {
	let url: URL
	
	init(extension: String = ".m4a") {
		let temp = URL(fileURLWithPath: NSTemporaryDirectory())
		url = temp.appendingPathComponent(UUID().uuidString + ".m4a")
	}
	
	var data: Data {
		return try! Data(contentsOf: url)
	}
	
	deinit {
		try? FileManager.default.removeItem(at: url)
	}
}
