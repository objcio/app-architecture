import UIKit

enum Subscription<A> {
	case playProgress(player: Player, handle: (TimeInterval?, _ isPlaying: Bool) -> A)
	case recordProgress(recorder: Recorder, handle: (TimeInterval?) -> A)
	case storeChanged(handle: (_ rootFolder: Folder) -> A)
}

extension Subscription {
	func map<B>(_ f: @escaping (A) -> B) -> Subscription<B> {
		switch self {
		case let .playProgress(player: player, handle: handle):
			return .playProgress(player: player, handle: { f(handle($0, $1)) })
		case let .recordProgress(recorder: recorder, handle: handle):
			return .recordProgress(recorder: recorder, handle: { f(handle($0)) })
		case let .storeChanged(handle):
			return .storeChanged(handle: { f(handle($0)) })
		}
	}
}


final class SubscriptionManager<Message> {
	var callback: (Message) -> ()
	var storeObservers: [Any] = []
	
	init(_ callback: @escaping (Message) -> ()) {
		self.callback = callback
	}
	
	func update(subscriptions: [Subscription<Message>]) {
		// Todo: here we should reuse existing observers, if possible?
		var newStoreObservers: [Any] = []
		for subscription in subscriptions {
			switch subscription {
			case .playProgress(let p, let f):
				p.update = { [weak self] position, isPlaying in self?.callback(f(position, isPlaying)) }
			case .recordProgress(recorder: let r, handle: let f):
				r.update = { [weak self] position in self?.callback(f(position)) }
			case .storeChanged(let handle):
				newStoreObservers.append(NotificationCenter.default.addObserver(forName: Store.changedNotification, object: nil, queue: nil) { [weak self] notification in
					self?.callback(handle(notification.object as! Folder))
				})
			}
		}
		for s in storeObservers {
			NotificationCenter.default.removeObserver(s)
		}
		storeObservers = newStoreObservers
	}
}

