import Cocoa

class NewItemViewController: NSViewController, NSTextFieldDelegate {
	@IBOutlet var textField: NSTextField!
	@IBOutlet var okButton: NSButton!
	
	var parentFolder: Folder?
	var recording: Recording?

	override func viewDidLoad() {
		super.viewDidLoad()
		okButton.isEnabled = false
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSControl.textDidChangeNotification, object: textField)
	}
	
	func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
		if textField.stringValue.isEmpty {
			return false
		}
		self.ok(self)
		return true
	}

	@IBAction func cancel(_ sender: Any?) {
		if recording != nil {
			self.presenting?.dismiss(nil)
		} else {
			self.dismiss(nil)
		}
	}
	
	@IBAction func ok(_ sender: Any?) {
		if let r = recording {
			r.setName(textField.stringValue)
			parentFolder?.add(r)
			parentFolder = nil
			self.presenting?.dismiss(nil)
		} else {
			parentFolder?.add(Folder(name: textField.stringValue, uuid: UUID()))
			parentFolder = nil
			self.dismiss(nil)
		}
	}
	
	@objc func textDidChange(_ notification: Notification) {
		okButton.isEnabled = !textField.stringValue.isEmpty
	}
}
