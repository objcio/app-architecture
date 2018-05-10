import UIKit

class FolderViewController: UITableViewController, RecordViewControllerDelegate {
	var store: Server!
	var folder: Folder! {
		didSet {
			tableView.reloadData()
			if let f = folder, let s = store, f.uuid != s.rootFolder.uuid {
				navigationItem.title = f.name
			} else {
				navigationItem.title = .recordings
			}
		}
	}
	
	var task: URLSessionTask?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftItemsSupplementBackButton = true
		navigationItem.leftBarButtonItem = editButtonItem
		
		refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
		reload()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidAppear(animated)
		task?.cancel()
		task = nil
	}

	@objc func reload() {
		guard folder.state != .loading else { return }
		
		folder.state = .loading
		refreshControl?.beginRefreshing()
		task = URLSession.shared.load(store!.contents(of: folder)) { result in
			self.refreshControl?.endRefreshing()
			guard case let .success(contents) = result else {
				dump(result) // TODO production error handling
				return
			}
			self.folder.contents = contents
			self.folder.state = .loaded
		}
	}

	var previousFolderViewController: FolderViewController? {
		if let viewControllers = navigationController?.viewControllers, let index = viewControllers.index(where: { $0 === self }), index > 0 {
			return viewControllers[index - 1] as? FolderViewController
		}
		return nil
	}
	
	var playViewController: PlayViewController? {
		if splitViewController?.viewControllers.count == 2, let playViewController = ((splitViewController?.viewControllers[1] as? UINavigationController)?.topViewController as? PlayViewController) {
			return playViewController
		}
		return nil
	}
	
	var selectedItem: Item? {
		if let indexPath = tableView.indexPathForSelectedRow {
			return folder.contents[indexPath.row]
		}
		return nil
	}
	
	// MARK: - Segues and actions
	
	@IBAction func createNewFolder(_ sender: Any) {
		modalTextAlert(title: .createFolder, accept: .create, placeholder: .folderName) { string in
			if let s = string {
				URLSession.shared.load(self.store.create(folderNamed: s, in: self.folder)) { result in
					guard case let .success(f) = result else { dump(result); return } // error
					self.insert(item: .folder(f))
				}
			}
         self.dismiss(animated: true)
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier else { return }
		if identifier == .showFolder {
			guard let folderVC = segue.destination as? FolderViewController, case let .folder(selectedFolder)? = selectedItem else { fatalError() }
			folderVC.store = store
			folderVC.folder = selectedFolder
		} else if identifier == .showRecorder {
			guard let recordVC = segue.destination as? RecordViewController else { fatalError() }
			recordVC.folder = folder
			recordVC.store = store
			recordVC.delegate = self
		} else if identifier == .showPlayer {
			guard
				let playVC = (segue.destination as? UINavigationController)?.topViewController as? PlayViewController,
				case let .recording(recording)? = selectedItem
			else { fatalError() }
			playVC.store = store
			playVC.recording = recording
			if let indexPath = tableView.indexPathForSelectedRow {
				tableView.deselectRow(at: indexPath, animated: true)
			}
		}
	}
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return folder.contents.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = folder.contents[indexPath.row]

		let identifier: String
		let text: String
		switch item {
		case let .folder(folder):
			identifier = "FolderCell"
			text = "📁 \(folder.name)"
		case let .recording(recording):
			identifier = "RecordingCell"
			text = "🔊 \(recording.name)"

		}
		
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		cell.textLabel!.text = text
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func deleteItem(item: Item) {
		guard let index = folder.contents.index(where: { $0.uuid == item.uuid }) else { return }
		folder.contents.remove(at: index)
		tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
	}
	
	func insert(item: Item) {
		self.folder.contents.append(item)
		self.tableView.insertRows(at: [IndexPath(row: self.folder.contents.endIndex-1, section: 0)], with: .automatic)
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else { return }
		let item = folder.contents[indexPath.row]
		switch item {
		case .folder:
			URLSession.shared.load(store.change(.delete, item: item)) { result in
				guard case .success = result else {
					dump(result) // TODO production error handling
					return
				}
				self.deleteItem(item: item)
			}
		case .recording(let recording):
			URLSession.shared.load(store.change(.delete, item: item)) { result in
				guard case .success = result else { dump(result); return }
				if let player = self.playViewController, player.recording?.uuid == recording.uuid {
					player.recording = nil
				}

				self.deleteItem(item: item)
			}
		}
	}

	
	// MARK: RecordViewDelegate
	
	func recordingAdded(_ result: Result<Recording>) {
		switch result {
		case .error(let e):
			print(e)
		case .success(let value):
			insert(item: .recording(value))
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	static let hostNameKey = "hostName"
	static let portKey = "port"
	static let showRecorder = "showRecorder"
	static let showPlayer = "showPlayer"
	static let showFolder = "showFolder"
	
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
}

