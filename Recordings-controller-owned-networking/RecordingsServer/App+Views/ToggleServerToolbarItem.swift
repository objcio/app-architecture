import Cocoa

class ToggleServerToolbarItem: NSToolbarItem {
	var toggleButton: NSButton!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		toggleButton = NSButton(title: "", target: self, action: #selector(toggleServer(_:)))
		toggleButton.frame = NSRect(x: 0, y: 0, width: 180, height: 32)
		toggleButton.autoresizingMask = [.width, .minXMargin]
		view = toggleButton
		self.minSize = NSMakeSize(150, 32)
		self.maxSize = NSMakeSize(180, 32)
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleServerStateChange(_:)), name: HttpServer.stateChanged, object: nil)
		guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
		handleServerStateChange(Notification(name: HttpServer.stateChanged, object: appDelegate.httpServer, userInfo: nil))
	}
	
	@objc func handleServerStateChange(_ notification: Notification) {
		guard let httpServer = notification.object as? HttpServer else { return }
		toggleButton.title = httpServer.isRunning ? .stopLabel : .startLabel
	}
	
	@IBAction func toggleServer(_ sender: Any?) {
		guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
		if appDelegate.isRunning {
			appDelegate.stop()
		} else {
			appDelegate.start()
		}
	}
}

extension String {
	static let startLabel = NSLocalizedString("🖥 Start server", comment: "")
	static let stopLabel = NSLocalizedString("🛑 Stop server", comment: "")
}
