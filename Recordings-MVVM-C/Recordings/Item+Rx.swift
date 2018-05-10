import RxSwift
import RxCocoa
import RxDataSources

extension Item: IdentifiableType, Hashable {
	var hashValue: Int { return uuid.hashValue }
	static func ==(lhs: Item, rhs: Item) -> Bool {
		return lhs.uuid == rhs.uuid
	}
	
	var identity: UUID { return uuid }
	
	var changeObservable: Observable<()> {
		return NotificationCenter.default.rx.notification(Store.changedNotification).filter { [weak self] (note) -> Bool in
			guard let s = self else { return false }
			if let item = note.object as? Item, item == s, !(note.userInfo?[Item.changeReasonKey] as? String == Item.removed) {
				return true
			} else if let userInfo = note.userInfo, userInfo[Item.parentFolderKey] as? Folder == s {
				return true
			}
			return false
		}.map { _ in () }
	}
	
	var deletedObservable: Observable<()> {
		return NotificationCenter.default.rx.notification(Store.changedNotification).filter { [weak self] (note) -> Bool in
			guard let s = self else { return false }
			if let item = note.object as? Item, item == s, note.userInfo?[Item.changeReasonKey] as? String == Item.removed {
				return true
			}
			return false
		}.map { _ in () }
	}
}
