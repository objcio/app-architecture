import AppKit

class OutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	@IBOutlet var outlineView: NSOutlineView!
	@IBOutlet var deleteButton: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		deleteButton.isEnabled = false
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}
	
	@IBAction func handleClick(_ sender: Any?) {
		if outlineView.clickedRow == -1 {
			outlineView.deselectAll(sender)
		}
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		outlineView.reloadData()
	}
	
	func outlineViewSelectionDidChange(_ notification: Notification) {
		deleteButton.isEnabled = outlineView.selectedRow != -1
		
		if let recording = outlineView.item(atRow: outlineView.selectedRow) as? Recording, let windowController = self.view.window?.delegate as? WindowController {
			windowController.playViewController?.recording = recording
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if let folder = item as? Folder {
			return folder.contents.count
		}
		return Store.shared.rootFolder.contents.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		return ((item as? Folder) ?? Store.shared.rootFolder).contents[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is Folder
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let cell = outlineView.makeView(withIdentifier: .emojiDecoratedCell, owner: self) as! EmojiDecoratedCellView
		if let f = item as? Folder {
			cell.emoji.stringValue = "📁"
			cell.textField!.stringValue = f.name
		} else if let r = item as? Recording {
			cell.emoji.stringValue = "🔊"
			cell.textField!.stringValue = r.name
		} else {
			return NSView()
		}
		return cell
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		if segue.identifier == .newFolder, let newItemViewController = segue.destinationController as? NewItemViewController {
			newItemViewController.parentFolder = (outlineView.item(atRow: outlineView.selectedRow) as? Folder) ?? Store.shared.rootFolder
			newItemViewController.recording = nil
		} else if segue.identifier == .newRecording, let recordViewController = segue.destinationController as? RecordViewController {
			recordViewController.folder = (outlineView.item(atRow: outlineView.selectedRow) as? Folder) ?? Store.shared.rootFolder
		}
	}
	
	@IBAction func newFolder(_ sender: Any?) {
		self.performSegue(withIdentifier: .newFolder, sender: sender)
	}
	
	@IBAction func newRecording(_ sender: Any?) {
		self.performSegue(withIdentifier: .newRecording, sender: sender)
	}
	
	@IBAction func delete(_ sender: Any?) {
		if let item = outlineView.item(atRow: outlineView.selectedRow) as? Item {
			item.parent?.remove(item)
		}
	}
}

extension NSUserInterfaceItemIdentifier {
	static let emojiDecoratedCell = NSUserInterfaceItemIdentifier("DataCell")
}

extension NSStoryboardSegue.Identifier {
	static let newFolder = NSStoryboardSegue.Identifier("newFolder")
	static let newRecording = NSStoryboardSegue.Identifier("newRecording")
}

