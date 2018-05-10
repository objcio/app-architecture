import Foundation

protocol NotifyingStore: class {
	associatedtype DataType: Codable
	
	static var shortName: String { get }
	static var defaultUrlForShared: URL { get }
	
	var content: DataType { get }
	var persistToUrl: URL? { get }
	var enableDebugLogging: Bool { get }
	
	func loadWithoutNotifying(jsonData: Data)
	func reloadAndNotify(jsonData: Data)
	func serialized() throws -> Data
	func commitAction<T>(_ changeValue: T, sideEffect: Bool)
	func addObserver<T>(actionType: T.Type, _ callback: @escaping (DataType, T?) -> ()) -> Observations
}

class Observations {
	var observations = [NSObjectProtocol]()
	init(_ observations: NSObjectProtocol...) {
		self.observations = observations
	}
	static func +=(_ l: Observations, _ r: Observations) {
		l.observations += r.observations
		r.observations.removeAll()
	}
	static func +=(_ l: Observations, _ r: NSObjectProtocol) {
		l.observations.append(r)
	}
	func cancel() {
		for o in observations {
			NotificationCenter.default.removeObserver(o)
		}
		observations.removeAll()
	}
	deinit {
		cancel()
	}
}

extension NotifyingStore {
	static var defaultUrlForShared: URL {
		return try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(Self.shortName).json")
	}
	
	var enableDebugLogging: Bool {
		#if DEBUG
			return true
		#else
			return false
		#endif
	}
	
	func postReloadNotification(jsonData: Data) {
		if enableDebugLogging {
			print("Restored \(Self.shortName) to:\n\(String(data: jsonData, encoding: .utf8)!)")
		}
		NotificationCenter.default.post(name: notifyingStoreReloadNotification, object: self)
	}
	
	func reloadAndNotify(jsonData: Data) {
		loadWithoutNotifying(jsonData: jsonData)
		postReloadNotification(jsonData: jsonData)
	}

	func serialized() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		return try encoder.encode(content)
	}
	
	func addObserver<T>(actionType: T.Type, _ callback: @escaping (DataType, T?) -> ()) -> Observations {
		let first = NotificationCenter.default.addObserver(forName: Notification.Name(String(describing: T.self)), object: self, queue: nil) { [weak self] n in
			if let change = n.userInfo?[notifyingStoreUserActionKey] as? T, let s = self {
				callback(s.content, change)
			}
		}
		let second = NotificationCenter.default.addObserver(forName: notifyingStoreReloadNotification, object: self, queue: nil) { [weak self] n in
			guard let s = self else { return }
			callback(s.content, nil)
		}
		callback(content, nil)
		return Observations(first, second)
	}
	
	func commitAction<T>(_ changeValue: T, sideEffect: Bool = false) {
		do {
			if persistToUrl != nil || enableDebugLogging {
				let data = try serialized()
				if let url = persistToUrl {
					try data.write(to: url)
				}
				if enableDebugLogging {
					print("Changed \(Self.shortName) to:\n\(String(data: data, encoding: .utf8)!)")
				}
			}
			
			NotificationCenter.default.post(name: Notification.Name(String(describing: T.self)), object: self, userInfo: [notifyingStoreUserActionKey: changeValue, notifyingStoreSideEffectKey: sideEffect])
		} catch {
			fatalError("Error: \(error)")
		}
	}
}

let notifyingStoreUserActionKey: String = "NotifyingStoreUserAction"
let notifyingStoreSideEffectKey: String = "NotifyingStoreSideEffect"
let notifyingStoreReloadNotification = Notification.Name("NotifyingStoreReloadNotification")

