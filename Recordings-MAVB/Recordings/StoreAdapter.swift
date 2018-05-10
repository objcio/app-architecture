import Foundation

struct StoreAdapter: SignalInterface, SignalInputInterface {
	var input: SignalInput<Message> { return filteredAdapter.input }
	var signal: Signal<Store> { return filteredAdapter.stateSignal }
	
	enum Message {
		case newFolder(named: String, parentUuid: UUID)
		case addRecording(Recording)
		case renameItem(uuid: UUID, newName: String)
		case removeItem(uuid: UUID)
		case record(inParent: UUID)
		case recordingComplete
		case deleteTemporary
		case save
	}
	
	private let filteredAdapter: FilteredAdapter<Message, Store, Store.Notification>
	init(store s: Store) {
		filteredAdapter = FilteredAdapter(initialState: s) { (store: inout Store, message: Message) -> Store.Notification in
			switch message {
			case .addRecording(let r): return store.addRecording(r)
			case .newFolder(let n, let p): return store.newFolder(named: n, parentUuid: p)
			case .removeItem(let u): return store.removeItem(uuid: u)
			case .renameItem(let u, let n): return store.renameItem(uuid: u, newName: n)
			case .record(let p): return store.createTemporary(parentUuid: p)
			case .recordingComplete: return store.recordingComplete()
			case .deleteTemporary: return store.deleteTemporary()
			case .save: return store.save()
			}
		}
	}
	
	func temporarySignal() -> Signal<Store.TempFile?> {
		return filteredAdapter.filteredSignal { s, notification, next in
			if case .temporary(let details) = (notification ?? Store.Notification.reload) {
				next.send(value: details)
			}
		}
	}
	
	func folderContentsSignal(_ folderUuid: UUID) -> Signal<ArrayMutation<Item>> {
		return filteredAdapter.filteredSignal(initialValue: []) { (
			items: inout [Item],
			store: Store,
			notification: Store.Notification?,
			next: SignalNext<SetMutation<Item>>) throws in
		
			switch notification ?? .reload {
			case .mutation(let m) where m.values.first?.parentUuid == folderUuid:
				next.send(value: m)
			case .reload:
				if let folder = store.content[folderUuid]?.folder {
					next.send(value: .reload(folder.childUuids.compactMap { store.content[$0] }))
				} else {
					throw SignalComplete.closed
				}
			default: break
			}
		}.sortedArrayMutation(equate: { $0.uuid == $1.uuid }, compare: { l, r in
			l.name == r.name ? l.uuid.uuidString < r.uuid.uuidString : l.name < r.name
		})
	}
	
	func recordingSignal(_ uuid: UUID) -> Signal<(rec: Recording, url: URL)> {
		return filteredAdapter.filteredSignal { store, notification, next in
			if notification?.affectsUuid(uuid, includingParent: false) ?? true {
				next.send(result: store.content[uuid]?.recording.map { .success(($0, store.fileURL(for: uuid))) } ?? .signalClosed)
			}
		}
	}
	
	func folderSignal(_ uuid: UUID) -> Signal<Folder> {
		return filteredAdapter.filteredSignal { store, notification, next in
			if notification?.affectsUuid(uuid, includingParent: false) ?? true {
				next.send(result: store.content[uuid]?.folder.map { .success($0) } ?? .signalClosed)
			}
		}
	}
}

extension Store.Notification {
	func affectsUuid(_ uuid: UUID, includingParent incP: Bool) -> Bool {
		switch self {
		case .mutation(let m):
			for i in m.values {
				if i.uuid == uuid || (incP && i.parentUuid == uuid) {
					return true
				}
			}
			fallthrough
		default: return false
		}
	}
}
