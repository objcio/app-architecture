import UIKit

struct FolderContext {
	let documentStore: DocumentStore
	let viewStateStore: ViewStateStore
	let index: Int
}

extension StoreContext {
	func folderContext(index: Int) -> FolderContext {
		return FolderContext(documentStore: documentStore, viewStateStore: viewStateStore, index: index)
	}
}

class FolderViewController: UITableViewController {
	var context: FolderContext! { willSet { precondition(!isViewLoaded) } }

	var observations = Observations()
	var cachedSortedUUIDs: [UUID] = []
	var state: FolderViewState?
	var folder: Folder?
	
	override func viewDidLoad() {
		super.viewDidLoad()

		// Set the title assuming that we're the last view controller pushed onto the stack.
		navigationItem.title = context.documentStore.content[context.viewStateStore.content.folderViews.last!.folderUUID]?.folder?.name ?? ""
		navigationItem.leftItemsSupplementBackButton = true

		observations.cancel()
		observations += context.viewStateStore.addObserver(actionType: FolderViewState.Action.self) { [unowned self] splitViewState, action in
			guard splitViewState.folderViews.indices.contains(self.context.index) else { return }
			self.state = splitViewState.folderViews[self.context.index]
			self.handleViewStateNotification(action: action)
		}
		observations += context.documentStore.addObserver(actionType: DocumentStore.Action.self) { [unowned self] (store, action) in
			guard let folderState = self.state, let folder = store[folderState.folderUUID]?.folder else { return }
			self.folder = folder
			self.handleStoreNotification(action: action)
		}
	}
	
	@objc func toggleEditing(_ sender: Any?) {
		guard let uuid = state?.folderUUID else { return }
		context.viewStateStore.toggleEditing(folderUUID: uuid)
	}

	func handleViewStateNotification(action: FolderViewState.Action?) {
		guard let state = self.state else { return }
		switch action {
		case .toggleEditing(let uuid)? where uuid == state.folderUUID:
			tableView?.setEditing(state.editing, animated: true)
			navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: state.editing ? .done : .edit, target: self, action: #selector(toggleEditing(_:)))
		case .toggleEditing?: break
		case .alreadyUpdatedScrollPosition?: break
		case nil:
			navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: state.editing ? .done : .edit, target: self, action: #selector(toggleEditing(_:)))
			tableView?.setEditing(state.editing, animated: false)
			tableView?.setContentOffset(CGPoint(x: 0, y: state.scrollOffset), animated: false)
		}
	}
	
	func updateCachedSortedUUIDs() {
		cachedSortedUUIDs = folder?.sortedChildUUIDs(in: context.documentStore) ?? []
	}
	
	func handleStoreNotification(action: DocumentStore.Action?) {
		guard let folder = self.folder else { return }
		switch action {
		case let .added(parentUUID, _, newIndex)? where parentUUID == folder.uuid:
			updateCachedSortedUUIDs()
			tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .left)
		case let .removed(parentUUID, _, oldIndex)? where parentUUID == folder.uuid:
			updateCachedSortedUUIDs()
			tableView.deleteRows(at: [IndexPath(row: oldIndex, section: 0)], with: .right)
		case let .renamed(parentUUID, _, oldIndex, newIndex)? where parentUUID == folder.uuid:
			updateCachedSortedUUIDs()
			if oldIndex != newIndex {
				tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
				tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .fade)
			} else {
				// A rename in-place looks better without animation
				tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .none)
			}
		case .added?: break
		case .removed?: break
		case .renamed?: break
		case nil:
			title = state?.folderUUID == DocumentStore.rootFolderUUID ? .recordings : folder.name
			updateCachedSortedUUIDs()
			tableView.reloadData()
		}
	}
	
	// MARK: - Segues and actions
	
	@IBAction func createNewFolder(_ sender: Any?) {
		guard let uuid = state?.folderUUID else { return }
		context.viewStateStore.showCreateFolder(parentUUID: uuid)
	}
	
	@IBAction func createNewRecording(_ sender: Any?) {
		guard let uuid = state?.folderUUID else { return }
		context.viewStateStore.showRecorder(parentUUID: uuid)
	}
	
	// MARK: - Table View
	
	func uuidAtIndexPath(_ indexPath: IndexPath) -> UUID? {
		guard cachedSortedUUIDs.indices.contains(indexPath.row) else { return nil }
		return cachedSortedUUIDs[indexPath.row]
	}
	
	var selectedUUID: UUID? {
		guard let indexPath = tableView.indexPathForSelectedRow else { return nil }
		return uuidAtIndexPath(indexPath)
	}
	
	func itemAtIndexPath(_ indexPath: IndexPath) -> Item? {
		guard let uuid = uuidAtIndexPath(indexPath) else { return nil }
		return context.documentStore.content[uuid]
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let item = itemAtIndexPath(indexPath) else { return }
		switch item {
		case .folder(let f): context.viewStateStore.pushFolder(f.uuid)
		case .recording(let r): context.viewStateStore.setPlaySelection(r.uuid, alreadyApplied: false)
		}
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cachedSortedUUIDs.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = itemAtIndexPath(indexPath)
		let identifier: String
		switch item {
		case .recording?: identifier = "RecordingCell"
		default: identifier = "FolderCell"
		}
		
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		switch item {
		case .folder(let f)?: cell.textLabel!.text = "📁  \(f.name)"
		case .recording(let r)?: cell.textLabel!.text = "🔊  \(r.name)"
		default: cell.textLabel!.text = ""
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete, let uuid = uuidAtIndexPath(indexPath) else { return }
		context.documentStore.removeItem(uuid: uuid)
	}
	
	override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		guard let uuid = state?.folderUUID else { return }
		context.viewStateStore.updateScrollPosition(folderUUID: uuid , scrollPosition: Double(tableView?.contentOffset.y ?? 0))
	}
	
	override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		guard let uuid = state?.folderUUID, decelerate == false else { return }
		context.viewStateStore.updateScrollPosition(folderUUID: uuid , scrollPosition: Double(tableView?.contentOffset.y ?? 0))
	}
}

fileprivate extension String {
	static let uuidKey = "uuid"
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
}

