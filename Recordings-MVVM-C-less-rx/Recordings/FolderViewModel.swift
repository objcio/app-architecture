import Foundation
import RxSwift
import RxCocoa
import RxDataSources

class FolderViewModel {
	var folder: Folder! {
		didSet {
			let newTitle = folder.parent == nil ? .recordings : folder.name
			navigationTitleSubject.onNext(newTitle)
			folderContentsSubject.onNext([
					AnimatableSectionModel(model: 0, items: folder.contents)
			])
		}
	}
	
	var navigationTitle: Observable<String> { return navigationTitleSubject }
	var folderContents: Observable<[AnimatableSectionModel<Int, Item>]> { return folderContentsSubject }
	
	private let navigationTitleSubject = ReplaySubject<String>.create(bufferSize: 1)
	private let folderContentsSubject = ReplaySubject<[AnimatableSectionModel<Int, Item>]>.create(bufferSize: 1)
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}

	@objc func handleChangeNotification(_ notification: Notification) {
		if let f = notification.object as? Folder, f === folder {
			let reason = notification.userInfo?[Item.changeReasonKey] as? String
			if reason == Item.removed {
				navigationTitleSubject.onNext("")
				folderContentsSubject.onNext([
					AnimatableSectionModel(model: 0, items: [])
				])
			} else {
				folder = f
			}
		}
		if let f = notification.userInfo?[Item.parentFolderKey] as? Folder, f === folder {
			folder = f
		}
	}

	func create(folderNamed name: String?) {
		guard let s = name else { return }
		let newFolder = Folder(name: s, uuid: UUID())
		folder.add(newFolder)
	}
	
	func deleteItem(_ item: Item) {
		folder.remove(item)
	}
	
	static func text(for item: Item) -> String {
		return "\((item is Recording) ? "🔊" : "📁")  \(item.name)"
	}
}

fileprivate extension String {
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
}

