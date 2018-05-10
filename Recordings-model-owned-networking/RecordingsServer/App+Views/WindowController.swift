import Cocoa

class WindowController: NSWindowController {
	var playViewController: PlayViewController? = nil
	
	override func windowDidLoad() {
		super.windowDidLoad()
		self.window!.titleVisibility = .hidden
		self.window!.backgroundColor = .white
	}
}

