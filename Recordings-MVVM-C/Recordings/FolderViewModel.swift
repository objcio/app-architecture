import Foundation
import RxSwift
import RxCocoa
import RxDataSources

class FolderViewModel {
	let folder: Variable<Folder>
	private let folderUntilDeleted: Observable<Folder?>
	
	init(initialFolder: Folder = Store.shared.rootFolder) {
		folder = Variable(initialFolder)
		folderUntilDeleted = folder.asObservable()
			// Every time the folder changes
			.flatMapLatest { currentFolder in
				// Start by emitting the initial value
				Observable.just(currentFolder)
					// Re-emit the folder every time a non-delete change occurs
					.concat(currentFolder.changeObservable.map { _ in currentFolder })
					// Stop when a delete occurs
					.takeUntil(currentFolder.deletedObservable)
					// After a delete, set the current folder back to `nil`
					.concat(Observable.just(nil))
			}.share(replay: 1)
	}
	
	func create(folderNamed name: String?) {
		guard let s = name else { return }
		let newFolder = Folder(name: s, uuid: UUID())
		folder.value.add(newFolder)
	}
	
	func deleteItem(_ item: Item) {
		folder.value.remove(item)
	}
	
	var navigationTitle: Observable<String> {
		return folderUntilDeleted.map { folder in
			guard let f = folder else { return "" }
			return f.parent == nil ? .recordings : f.name
		}
	}
	
	var folderContents: Observable<[AnimatableSectionModel<Int, Item>]> {
		return folderUntilDeleted.map { folder in
			guard let f = folder else { return [AnimatableSectionModel(model: 0, items: [])] }
			return [AnimatableSectionModel(model: 0, items: f.contents)]
		}
	}
	
	static func text(for item: Item) -> String {
		return "\((item is Recording) ? "🔊" : "📁")  \(item.name)"
	}
}

fileprivate extension String {
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
}

