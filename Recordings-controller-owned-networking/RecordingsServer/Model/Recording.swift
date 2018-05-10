import Foundation

class Recording: Item {
	var fileURL: URL? {
		return store?.fileURL(for: self)
	}
	override func deleted() {
		if let url = fileURL {
			_ = try? FileManager.default.removeItem(at: url)
		}
		super.deleted()
	}
}
