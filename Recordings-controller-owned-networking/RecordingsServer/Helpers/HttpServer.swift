import Foundation

/// The `HttpServer` class is just a public interface for starting and stopping the `SocketListener` and getting basic is-running information.
public class HttpServer {
	public static let stateChanged = NSNotification.Name(rawValue: "HttpServerStateChanged")

	private enum InternalState { case inactive(Swift.Error?), active(SocketListener) }
	private var internalState: InternalState = .inactive(nil)
	
	init() {}
	
	public func start(serverInfo: HttpServerInfo, handlers: Array<HttpResponseHandler.Type>) {
		do {
			internalState = .active(try SocketListener(serverInfo: serverInfo, handlers: handlers))
		} catch {
			internalState = .inactive(error)
		}
		NotificationCenter.default.post(name: HttpServer.stateChanged, object: self)
	}
	
	public func stop() {
		internalState = .inactive(nil)
		NotificationCenter.default.post(name: HttpServer.stateChanged, object: self)
	}
	
	public var error: Error? {
		switch internalState {
		case .inactive(let e): return e
		case .active: return nil
		}
	}
	
	public var port: UInt16? {
		switch internalState {
		case .inactive: return nil
		case .active(let listener): return ipv4Port(fileHandle: listener.ipv4Handle)
		}
	}
	
	public var isRunning: Bool {
		switch internalState {
		case .active: return true
		default: return false
		}
	}
}

/// The `SocketListener` is the true "server" that listens for incoming TCP connections on a port and spawns an HttpConnection for each attempt.
/// A `NetService` is also spawned to advertise the server on the local domain using the provided service name.
fileprivate class SocketListener: NSObject, NetServiceDelegate {
	weak var httpServer: HttpServer?
	let ipv4Handle: FileHandle
	let ipv6Handle: FileHandle
	let netService: NetService
	let handlers: Array<HttpResponseHandler.Type>
	let serverInfo: HttpServerInfo
	var connections: Set<HttpConnection>
	
	// In the current implementation, the server always runs on an application-assigned port and on all interfaces.
	let serverPort: UInt16 = 0
	let serverIpv4Address: UInt32 = INADDR_ANY
	let serverIpv6Address: in6_addr = in6addr_any

	init(serverInfo: HttpServerInfo, handlers: Array<HttpResponseHandler.Type>) throws {
		self.handlers = handlers
		self.serverInfo = serverInfo
		connections = []
		
		let ipv4Socket = try checkNotMinus1 { socket(PF_INET, SOCK_STREAM, IPPROTO_TCP) }
		let ipv6Socket = try checkNotMinus1 { socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP) }
		
		var enable: Int32 = 1
		try checkNotMinus1 { setsockopt(ipv4Socket, SOL_SOCKET, SO_REUSEADDR, &enable, UInt32(MemoryLayout<Int32>.size)) }
		try checkNotMinus1 { setsockopt(ipv6Socket, SOL_SOCKET, SO_REUSEADDR, &enable, UInt32(MemoryLayout<Int32>.size)) }
		try checkNotMinus1 { fcntl(ipv4Socket, F_SETFL, O_NONBLOCK) }
		try checkNotMinus1 { fcntl(ipv6Socket, F_SETFL, O_NONBLOCK) }
		
		var addr_in = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: UInt8(AF_INET), sin_port: UInt16(serverPort).bigEndian, sin_addr: in_addr(s_addr: serverIpv4Address.bigEndian), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
		try withUnsafePointer(to: &addr_in) { try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
			_ = try checkNotMinus1 { Darwin.bind(ipv4Socket, addrPtr, UInt32(MemoryLayout<sockaddr_in>.size)) }
		} }
		try checkNotMinus1 { listen(ipv4Socket, SOMAXCONN) }
		ipv4Handle = FileHandle(fileDescriptor: ipv4Socket, closeOnDealloc: true)
		
		var addr_in6 = sockaddr_in6(sin6_len: UInt8(MemoryLayout<sockaddr_in6>.size), sin6_family: UInt8(AF_INET6), sin6_port: ipv4Port(fileHandle: ipv4Handle).bigEndian, sin6_flowinfo: 0, sin6_addr: serverIpv6Address, sin6_scope_id: 0)
		try withUnsafePointer(to: &addr_in6) { try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
			_ = try checkNotMinus1 { Darwin.bind(ipv6Socket, addrPtr, UInt32(MemoryLayout<sockaddr_in6>.size)) }
		} }
		try checkNotMinus1 { listen(ipv6Socket, SOMAXCONN) }
		ipv6Handle = FileHandle(fileDescriptor: ipv6Socket, closeOnDealloc: true)
		
		netService = NetService(domain: "local.", type: "_\(serverInfo.serviceName)._tcp.", name: "", port: Int32(ipv4Port(fileHandle: ipv4Handle)))
		
		super.init()
		
		NotificationCenter.default.addObserver(forName: .NSFileHandleConnectionAccepted, object: ipv4Handle, queue: .main) { [weak self] n in
			guard let s = self, let fileHandle = n.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { return }
			s.connections.insert(HttpConnection(serverInfo: s.serverInfo, listener: s, fileHandle: fileHandle))
			s.ipv4Handle.acceptConnectionInBackgroundAndNotify()
		}
		NotificationCenter.default.addObserver(forName: .NSFileHandleConnectionAccepted, object: ipv6Handle, queue: .main) { [weak self] n in
			guard let s = self, let fileHandle = n.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { return }
			s.connections.insert(HttpConnection(serverInfo: s.serverInfo, listener: s, fileHandle: fileHandle))
			s.ipv6Handle.acceptConnectionInBackgroundAndNotify()
		}
		
		ipv4Handle.acceptConnectionInBackgroundAndNotify()
		ipv6Handle.acceptConnectionInBackgroundAndNotify()
		
		netService.publish()
	}
	
	func handlerForRequest(method: String, url: URL, headers: [String: String]) -> HttpResponseHandler.Type {
		for h in handlers {
			if h.canHandle(method: method, url: url, headers: headers) {
				return h
			}
		}
		return ErrorResponseHandler.self
	}
	
	deinit {
		netService.stop()
		ipv4Handle.closeFile()
		ipv6Handle.closeFile()
		for connection in connections {
			connection.cancel()
		}
	}
}

/// The `HttpConnection` object manages communication on each socket spawned by `accept`, reading the HTTP headers, starting response handler to handle the message once headers are complete and managing lifetime aspects of the connection.
/// The current implementation is basically HTTP/1.0 – in particular, it does not support pipelining/persistence or 100 Continue from HTTP/1.1.
/// NOTE: if this class is upgraded to HTTP/1.1, the default `createResponse` function in `HttpRequestHandler` will need to be updated to include that information in the response header.
///
/// THREAD SAFETY: All public members are threadsafe (serialized using a DispatchQueue as a private mutex). Read and write callbacks are invoked serially but on their own (arbitrary) thread.
public class HttpConnection: Hashable {
	public var hashValue: Int { return Unmanaged.passUnretained(self).toOpaque().hashValue }
	public static func ==(lhs: HttpConnection, rhs: HttpConnection) -> Bool { return lhs === rhs }
	
	// In the current implementation, the maximum HTTP header size is hard-coded to 8kB.
	private let maximumHeaderSize = 8 * 1024

	private weak var socketListener: SocketListener?
	private var fileHandle: FileHandle?
	private var idleTimer: DispatchSourceTimer?
	private var idleTimeout: TimeInterval = 20.0
	private var maximumConnectionDuration: TimeInterval = 60.0
	private var receivedHeaderSize = 0
	private var startDate = mach_absolute_time()
	private var queuedWrites = [Data]()
	private var progress = 0
	private var responseStarted = false

	private var handler: HttpResponseHandler? { didSet {
		if let h = oldValue {
			// Cancelled is always called on the global queue to avoid the possibility of lock re-entrancy
			DispatchQueue.global().async { h.cancelled() }
		}
	} }

	private let serverInfo: HttpServerInfo
	private let request: CFHTTPMessage
	private let queue = DispatchQueue(label: "")

	fileprivate init(serverInfo: HttpServerInfo, listener: SocketListener, fileHandle: FileHandle) {
		var enable: Int32 = 1
		// `SO_NOSIGPIPE` isn't available on Linux – you need to use `send` instead of `write` and pass `MSG_NOSIGNAL` (which doesn't exist on Darwin)
		setsockopt(fileHandle.fileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &enable, UInt32(MemoryLayout<Int32>.size))
		
		// Disable Nagle's algorithm. By default, HTTP sends in reasonable chunks already.
		setsockopt(fileHandle.fileDescriptor, IPPROTO_TCP, TCP_NODELAY, &enable, UInt32(MemoryLayout<Int32>.size))

		self.serverInfo = serverInfo
		self.socketListener = listener
		self.fileHandle = fileHandle
		self.request = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
		
		updateTimerInternal()
		
		fileHandle.readabilityHandler = { [weak self] fh in
			guard let s = self else { return }
			s.readabilityHandler()
		}
	}
	
	private func updateTimerInternal() {
		guard fileHandle != nil else { return }
		let currentDate = Double(mach_absolute_time() - startDate) / Double(NSEC_PER_SEC)
		guard currentDate < maximumConnectionDuration else {
			cancelInternal()
			return
		}
		
		if currentDate + idleTimeout > maximumConnectionDuration {
			idleTimeout = maximumConnectionDuration - currentDate
		}
		
		idleTimer = DispatchSource.singleTimer(interval: DispatchTimeInterval.fromSeconds(idleTimeout), leeway: .seconds(2), queue: queue) { [weak self] in
			self?.cancelInternal()
		}
	}
	
	/// The default idle timeout is intentionally low (20s) to limit bad behaviors. Handlers can change the default idle timeout, if necessary.
	public func setIdleTimeout(_ interval: TimeInterval) {
		queue.sync {
			self.idleTimeout = interval
			self.updateTimerInternal()
		}
	}
	
	/// The default maximum connection duration is intentionally low (60s) to limit bad behaviors. Handlers can change the default idle timeout, if necessary.
	public func setMaximumConnectionDuration(_ interval: TimeInterval) {
		queue.sync {
			self.maximumConnectionDuration = interval
			self.updateTimerInternal()
		}
	}
	
	private func startHandler() {
		let method = CFHTTPMessageCopyRequestMethod(request)?.takeRetainedValue() as String?
		let url = CFHTTPMessageCopyRequestURL(request)?.takeRetainedValue() as URL?
		let headers = CFHTTPMessageCopyAllHeaderFields(request)?.takeRetainedValue() as? Dictionary<String, String>
		let data = CFHTTPMessageCopyBody(request)
		CFHTTPMessageSetBody(request, Data() as CFData)
		
		guard let m = method, let u = url, let hs = headers, let handlerType = socketListener?.handlerForRequest(method: m, url: u, headers: hs) else {
			cancel()
			return
		}
		
		// Start
		do {
			// From this statement, handler is active and all members must be accessed inside queue
			let h = try handlerType.init(serverInfo: serverInfo, method: m, url: u, headers: hs)
			
			// Store the handler
			queue.sync { handler = h }
			
			// Let the handler begin
			try h.receiveConnection(self)
			
			// Send any body data already received
			if let d = data?.takeRetainedValue() as Data?, d.count > 0 {
				try h.receiveBodyFragment(d, connection: self)
			}
		} catch let error as HttpStatusCode {
			sendErrorIfPossible(error)
		} catch {
			cancel()
		}
	}
	
	private func sendErrorIfPossible(_ error: HttpStatusCode) {
		do {
			let h = try ErrorResponseHandler(serverInfo: serverInfo, method: "", url: URL(string: "http://ignore")!, headers: [:], code: error)
			var shouldRespond = false
			queue.sync {
				if responseStarted == false {
					handler = h
					shouldRespond = true
				}
			}
			if shouldRespond {
				try h.receiveConnection(self)
			}
		} catch {
			cancel()
		}
	}
	
	private func readabilityHandler() {
		guard let data = fileHandle?.availableData, data.count > 0 else {
			// End of read, close the file handle
			fileHandle?.readabilityHandler = nil
			cancel()
			return
		}

		var abortRead = false
		var h: HttpResponseHandler?
		queue.sync {
			// Enforce a maximum header size of 8kb to limit bad behavior
			if handler == nil {
				receivedHeaderSize += data.count
				if receivedHeaderSize > maximumHeaderSize {
					sendErrorIfPossible(HttpStatusCode.requestHeaderFieldsTooLarge)
					abortRead = true
				}
			}
			h = handler
		}
		if abortRead {
			fileHandle?.readabilityHandler = nil
			return
		}
		
		if h != nil {
			// Don't call into handler within queue
			do {
				try h?.receiveBodyFragment(data, connection: self)
			} catch let error as HttpStatusCode {
				sendErrorIfPossible(error)
			} catch {
				cancel()
			}
		} else {
			// We know we dont' have an active handler so direct access to request is safe
			guard data.withUnsafeBytes({ dataPtr in CFHTTPMessageAppendBytes(request, dataPtr, data.count) }) else {
				fileHandle?.readabilityHandler = nil
				cancel()
				return
			}
			if CFHTTPMessageIsHeaderComplete(request) {
				startHandler()
			}
		}

		queue.sync { updateTimerInternal() }
	}
	
	private func writeabilityHandler() {
		// Perform the write and access to the buffers inside the queue
		let (needCancel, needWriteBufferEmpty) = queue.sync { () -> (Bool, HttpResponseHandler?) in
			guard let buffer = queuedWrites.first, let fd = fileHandle?.fileDescriptor else { return (false, nil) }
			let written = buffer.withUnsafeBytes { (bufPtr: UnsafePointer<UInt8>) -> Int in
				Darwin.write(Int32(fd), bufPtr, Int(buffer.count - progress))
			}
			guard written != -1 else { return (true, nil) }
			progress += written
			if progress == buffer.count {
				queuedWrites.removeFirst()
				progress = 0
				if queuedWrites.isEmpty {
					fileHandle?.writeabilityHandler = nil
					if handler == nil {
						// Successful completion
						return (true, nil)
					} else {
						// Handler has not called close so notify it and continue
						return (false, handler)
					}
				}
			}
			return (false, nil)
		}
		
		if needCancel {
			cancel()
			return
		} else {
			// Notify handler that buffers are empty
			do {
				try needWriteBufferEmpty?.writeBufferEmpty(connection: self)
				updateTimerInternal()
			} catch {
				cancel()
			}
		}

		queue.sync { updateTimerInternal() }
	}
	
	public func write(sender: HttpResponseHandler, data: Data) {
		queue.sync {
			guard handler === sender else { return }
			responseStarted = true
			queuedWrites.append(data)
			if let fh = fileHandle, fh.writeabilityHandler == nil {
				fileHandle?.writeabilityHandler = { [weak self] fh in
					guard let s = self else { return }
					s.writeabilityHandler()
				}
			}
		}
	}
	
	public func close() {
		let h = queue.sync { () -> HttpResponseHandler? in
			let h = handler
			handler = nil
			return queuedWrites.isEmpty ? h : nil
		}
		if h != nil {
			cancel()
		}
	}
	
	private func cancelInternal() {
		handler = nil
		fileHandle?.closeFile()
		fileHandle = nil
		idleTimer?.cancel()
		idleTimer = nil
		socketListener?.connections.remove(self)
	}
	
	public func cancel() {
		queue.sync { cancelInternal() }
	}
}

/// This class is a repository of information about an HTTP request currently being processed and a series of convenience methods for turning that information into a serialized response.
/// This class is intended to be subclassed and method overridden. In particular, `canHandle` and `startResponse` will probably need to be overridden by *every* subclass. The `maximumContentLength` will need to be overridden by any `POST` handlers. The `receiveBodyFragment` and `writeBufferEmpty` methods might need to be overridden if you intended to process input or output data in a streamed fashion. The `cancelled` method might need to be overridden if you need to stop any asynchronous tasks if the connection is closed for any reason.
///
/// THREAD SAFETY: the `HttpConnection` will create and call most methods in a serial fashion from an unspecified background thread. Your own handler methods will probably need to ensure thread safety between this callback context and the execution context of your data.
/// The `cancelled` method is the only exception to the serialization of callbacks – its thread is unspecified (could be the connection's callback thread or could be any thread that invokes `cancelled` on the connection for any reason).
/// The `receivedData` is the only mutable member of this class – it is threadsafe during any callback and never mutated after `expectedContentLength` is reached but you must ensure safe access if you use it while it is still accumulating data.
public class HttpResponseHandler {
	public let serverInfo: HttpServerInfo
	public let url: URL
	public let method: String
	public let headers: Dictionary<String, String>
	public let expectedContentLength: Int
	public var receivedData = Data()

	/// When `start`ed, the `HttpServer` is given an array of response handlers. Each handler is asked in turn if it wants to handle any HTTP request that arrives and the first to respond `true` to this function is given control of the connection.
	class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return false
	}
	
	/// Construction is in two parts. This `init` method is Part 1 of construction. It lets the handler process the header and throw an error if the headers are invalid. Data other than a thrown error can't be written until Part 2 (the `receiveConnection` method) is called.
	public required init(serverInfo: HttpServerInfo, method: String, url: URL, headers: [String: String]) throws {
		self.serverInfo = serverInfo
		self.method = method
		self.url = url
		self.headers = headers
		
		if let lengthString = headers["Content-Length"], let length = Int(lengthString) {
			expectedContentLength = length
			if length > maximumContentLength {
				throw HttpStatusCode.payloadTooLarge
			}
		} else {
			expectedContentLength = 0
		}
	}
	
	/// Default content length is *zero* (disabled). If POST body data is required, override this.
	var maximumContentLength: Int {
		return 0
	}
	
	/// Convenience method for creating a `CFHTTPMessage` for the response with the status code and correct `Server` header.
	func createResponse(code: HttpStatusCode) -> CFHTTPMessage {
		let response = CFHTTPMessageCreateResponse(nil, code.rawValue, nil, kCFHTTPVersion1_0).takeRetainedValue()
		CFHTTPMessageSetHeaderFieldValue(response, "Server" as CFString, "\(serverInfo.serviceName)/\(serverInfo.version)" as CFString)
		return response
	}
	
	/// Convenience method for creating a `CFHTTPMessage` for the response with the status code, correct server header, content type header, data payload and content-length header and additional headers as provided.
	func createResponse(code: HttpStatusCode, mimeType: String, data: Data?, additionalHeaders: Dictionary<String, String> = [:]) -> CFHTTPMessage {
		let response = createResponse(code: code)
		CFHTTPMessageSetHeaderFieldValue(response, "Content-Type" as CFString, mimeType as CFString)
		for (key, value) in additionalHeaders {
			CFHTTPMessageSetHeaderFieldValue(response, key as CFString, value as CFString)
		}
		if let d = data {
			CFHTTPMessageSetHeaderFieldValue(response, "Content-Length" as CFString, "\(d.count)" as CFString)
			CFHTTPMessageSetBody(response, d as CFData)
		}
		return response
	}
	
	/// Convenience method for serializing a mesasge, writing it to the connection and immediately closing (do not use this function if you want to stream the result).
	func sendReponse(_ response: CFHTTPMessage, connection: HttpConnection) {
		guard let data = CFHTTPMessageCopySerializedMessage(response)?.takeRetainedValue() else {
			connection.close()
			return
		}
		connection.write(sender: self, data: data as Data)
		connection.close()
	}
	
	/// Convenience method for calling `createResponse` and `sendResponse`
	func sendResponse(code: HttpStatusCode, mimeType: String, data: Data?, additionalHeaders: Dictionary<String, String> = [:], connection: HttpConnection) {
		let response = createResponse(code: code, mimeType: mimeType, data: data, additionalHeaders: additionalHeaders)
		sendReponse(response, connection: connection)
	}
	
	/// Convenience method for sending a response with the given status and a very basic HTML content displaying the standard message associated with that code.
	/// As the name indicates, predominantely used for sending error reponses.
	func sendErrorResponse(code: HttpStatusCode, connection: HttpConnection) {
		// Create a dummy message to copy the default status message for the status code
		let dummy = createResponse(code: code)
		let statusMessage = String(((CFHTTPMessageCopyResponseStatusLine(dummy)?.takeRetainedValue())! as String).dropFirst(9))
		
		let bodyString = "<html><head><title>\(statusMessage)</title></head><body><h1>\(statusMessage)</h1></body></html>"
		let bodyData = bodyString.data(using: .utf8)!
		sendResponse(code: code, mimeType: "text/hhtml", data: bodyData, connection: connection)
	}
	
	/// Construction is in two parts. This `receiveConnection` method is Part 2 of construction. It lets the handler start sending a response.
	/// It's normally easier to override the `startResponse` method instead of this one since that method will ensure that expected body data is fully received before being called. However, if you're not expecting a `Content-Length` header or
	/// NOTE: As much as possible, if you intend to `throw` an error, do so before sending any data to the `connection` since after data is sent, any `throw` will no longer send a well-formed HTTP response and will instead merely cancel the connection.
	func receiveConnection(_ connection: HttpConnection) throws {
		if expectedContentLength == 0 {
			try startResponse(connection: connection)
		}
	}
	
	/// This function is called as data arrives after the HTTP header. The default behavior is simply to accumulate data in a `Data` instance which can be used in `startResponse` after the content is fully received.
	func receiveBodyFragment(_ data: Data, connection: HttpConnection) throws {
		if receivedData.count + data.count > expectedContentLength {
			throw HttpStatusCode.badRequest
		}
		receivedData.append(data)
		if receivedData.count == expectedContentLength {
			try startResponse(connection: connection)
		}
	}
	
	/// Overriding this method is the easiest way to handle a connection. If you override the `receiveConnection` and `receiveBodyFragment` methods to handle the processing of the request yourself, you are not required to call this function – it is merely a convenient "hook" point.
	func startResponse(connection: HttpConnection) throws {
		throw HttpStatusCode.notImplemented
	}
	
	/// Invoked by the `HttpConnection` when the write socket is able to send data without blocking. Override this to stream an output rather than outputting all at once.
	func writeBufferEmpty(connection: HttpConnection) throws {
	}
	
	/// Called at the end of the connection, successful or otherwise
	func cancelled() {
	}
}

/// A handler that sends very basic HTTP responses reporting an HTTP status code, generally intended for errors.
/// This handler is the fallback handler – if handler in the list of handlers reports that it can handle an incoming request, this handler is used to send a `.notFound` response.
class ErrorResponseHandler: HttpResponseHandler {
	override class func canHandle(method: String, url: URL, headers: [String: String]) -> Bool {
		return true
	}

	let code: HttpStatusCode
	required init(serverInfo: HttpServerInfo, method: String, url: URL, headers: [String: String]) throws {
		code = HttpStatusCode.notFound
		try super.init(serverInfo: serverInfo, method: method, url: url, headers: headers)
	}

	init(serverInfo: HttpServerInfo, method: String, url: URL, headers: [String: String], code: HttpStatusCode) throws {
		self.code = code
		try super.init(serverInfo: serverInfo, method: method, url: url, headers: headers)
	}

	override func startResponse(connection: HttpConnection) throws {
		sendErrorResponse(code: code, connection: connection)
	}
}

/// The standard HTTP status codes as a Swift `enum`.
enum HttpStatusCode: Int, Error {
	case `continue` = 100
	case switchingProtocols = 101
	case processing = 102
	case ok = 200
	case created = 201
	case accepted = 202
	case nonAuthoritativeInformation = 203
	case noContent = 204
	case resetContent = 205
	case partialContent = 206
	case multiStatus = 207
	case alreadyReported = 208
	case imUsed = 226
	case multipleChoices = 300
	case movedPermanently = 301
	case found = 302
	case seeOther = 303
	case notModified = 304
	case useProxy = 305
	case switchProxy = 306
	case temporaryRedirect = 307
	case permanentRedirect = 308
	case badRequest = 400
	case unauthorized = 401
	case paymentRequired = 402
	case forbidden = 403
	case notFound = 404
	case methodNotAllowed = 405
	case notAcceptable = 406
	case proxyAuthenticationRequired = 407
	case requestTimeout = 408
	case conflict = 409
	case gone = 410
	case lengthRequired = 411
	case preconditionFailed = 412
	case payloadTooLarge = 413
	case uriTooLong = 414
	case unsupportedMediaType = 415
	case rangeNotSatisfiable = 416
	case expectationFailed = 417
	case imATeapot = 418
	case misdirectedRequest = 421
	case unprocessableEntity = 422
	case locked = 423
	case failedDependency = 424
	case upgradeRequired = 426
	case preconditionRequired = 428
	case tooManyRequests
	case requestHeaderFieldsTooLarge = 431
	case unavailableForLegalReasons = 451
	case internalServerError = 500
	case notImplemented = 501
	case badGateway = 502
	case serviceUnavailable = 503
	case hatewayTimeout = 504
	case httpVersionNotSupported = 505
	case variantAlsoNegotiates = 506
	case insufficientStorage = 507
	case loopDetected = 508
	case notExtended = 510
	case networkAuthenticationRequired = 511
}

/// If you need to pass any global information to all response handlers, you could add it to this struct. The default information is merely the servive and and the server version.
public struct HttpServerInfo {
	public let serviceName: String
	public let version: String
	
	/// WARNING: the `serviceName` value is passed as the `type` parameter to `NetService` as follows:
	///    "_\(serviceName)._tcp."
	/// and must therefore obey the fules for such a value. The `version` string should be a valid semantic version string.
	public init(serviceName: String, version: String) {
		self.serviceName = serviceName
		self.version = version
	}
}

extension DispatchSource {
	// A basic Dispatch timer wrapper
	fileprivate class func singleTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval = .seconds(0), queue: DispatchQueue, handler: @escaping () -> Void) -> DispatchSourceTimer {
		let result = DispatchSource.makeTimerSource(queue: queue)
		result.setEventHandler(handler: handler)
		result.schedule(deadline: DispatchTime.now() + interval, leeway: leeway)
		result.resume()
		return result
	}
}

extension DispatchTimeInterval {
	// Secondsto `DispatchTimeInterval` conversion
	fileprivate static func fromSeconds(_ seconds: Double) -> DispatchTimeInterval {
		if MemoryLayout<Int>.size < 8 {
			return .milliseconds(Int(seconds * Double(NSEC_PER_SEC / NSEC_PER_MSEC)))
		} else {
			return .nanoseconds(Int(seconds * Double(NSEC_PER_SEC)))
		}
	}

	// `DispatchTimeInterval` to seconds conversion
	fileprivate func toSeconds() -> Double {
		#if swift (>=3.2)
			switch self {
			case .seconds(let t): return Double(t)
			case .milliseconds(let t): return (1.0 / Double(NSEC_PER_MSEC)) * Double(t)
			case .microseconds(let t): return (1.0 / Double(NSEC_PER_USEC)) * Double(t)
			case .nanoseconds(let t): return (1.0 / Double(NSEC_PER_SEC)) * Double(t)
			case .never: return Double.infinity
			}
		#else
			switch self {
			case .seconds(let t): return Double(t)
			case .milliseconds(let t): return (1.0 / Double(NSEC_PER_MSEC)) * Double(t)
			case .microseconds(let t): return (1.0 / Double(NSEC_PER_USEC)) * Double(t)
			case .nanoseconds(let t): return (1.0 / Double(NSEC_PER_SEC)) * Double(t)
			}
		#endif
	}
}

// Convenience function for checking socket results
enum SocketError: Error { case socketCreateFailed(Int32) }
@discardableResult func checkNotMinus1(_ f: () -> Int32) throws -> Int32 {
	let r = f()
	guard r != -1 else { throw SocketError.socketCreateFailed(errno) }
	return r
}

// Convenience function for getting the IPv4 address port from a `FileHandle`
func ipv4Port(fileHandle: FileHandle) -> UInt16 {
	var addr_in = sockaddr_in()
	withUnsafeMutablePointer(to: &addr_in) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
		var length = UInt32(MemoryLayout<sockaddr_in>.size)
		getsockname(fileHandle.fileDescriptor, addrPtr, &length)
		} }
	return UInt16(bigEndian: addr_in.sin_port)
}

