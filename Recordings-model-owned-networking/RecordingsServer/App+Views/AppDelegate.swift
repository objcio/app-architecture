import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	let httpServer = HttpServer()
	
	var isRunning: Bool { return httpServer.isRunning }
	
	func start() {
		httpServer.start(serverInfo: HttpServerInfo(serviceName: "recordings", version: "0.1"), handlers: [
			StreamResponseHandler.self,
			ChangeResponseHandler.self,
			ContentsResponseHandler.self,
			UuidResponseHandler.self
		])
	}
	
	func stop() {
		httpServer.stop()
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
	}
}

