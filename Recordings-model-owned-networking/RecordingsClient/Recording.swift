import Foundation

class Recording: Item {
	var fileURL: URL? {
		return store?.fileURL(for: self)
	}

	override func deleted() {
		if let url = fileURL {
			try? FileManager.default.removeItem(at: url)
		}
		super.deleted()
	}
}

extension Recording {
	var streamURL: URL? {
		guard let s = store else { return nil }
		if let url = fileURL, FileManager.default.fileExists(atPath: url.path) {
			return fileURL
		} else {
			return URL(string: "\(s.serverURL)/stream/\(uuid.uuidString)")!
		}
	}
}
