import Cocoa

class BackgroundView: NSView {
	@IBInspectable var backgroundColor: NSColor = .clear
	override func draw(_ dirtyRect: NSRect) {
		backgroundColor.setFill()
		NSBezierPath(rect: dirtyRect).fill()
	}
}
