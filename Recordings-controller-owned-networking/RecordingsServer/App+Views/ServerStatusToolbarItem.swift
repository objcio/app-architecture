import Cocoa

class ServerStatusToolbarItem: NSToolbarItem {
	var statusLabel: NSTextField!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		let layout = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 32))
		statusLabel = NSTextField(labelWithString: "")
		statusLabel.frame = NSRect(x: 0, y: 0, width: 350, height: 24)
		statusLabel.autoresizingMask = [.width]
		statusLabel.alignment = .right
		layout.addSubview(statusLabel)
		view = layout
		
		self.minSize = NSMakeSize(150, 32)
		self.maxSize = NSMakeSize(350, 32)
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleServerStateChange(_:)), name: HttpServer.stateChanged, object: nil)
		guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
		handleServerStateChange(Notification(name: HttpServer.stateChanged, object: appDelegate.httpServer, userInfo: nil))
	}
	
	@objc func handleServerStateChange(_ notification: Notification) {
		guard let httpServer = notification.object as? HttpServer else { return }
		if let port = httpServer.port {
			// Not an accident... render the port as a string so it avoids number formatting but use `localizedStringWithFormat` so a localization can reorder it within the output string.
			statusLabel.stringValue = String.localizedStringWithFormat(.activeState, "\(port)")
		} else {
			statusLabel.stringValue = .inactiveState
		}
	}
}

extension String {
	static let inactiveState = NSLocalizedString("Recordings server not running.", comment: "")
	static let activeState = NSLocalizedString("Recordings server running on port %@", comment: "")
}
