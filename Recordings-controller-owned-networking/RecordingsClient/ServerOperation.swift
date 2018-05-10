import Foundation

class ServerOperation {
	let hostName: String
	var port: Int
	var name: String
	var uuid: UUID?
	var task: URLSessionDataTask?
	init(name: String, hostName: String, port: Int) {
		self.name = name
		self.hostName = hostName
		self.port = port
		self.uuid = nil
		self.task = nil
	}
	
	func start(_ completion: @escaping (ServerOperation) -> ()) {
		let url = URL(string: "http://\(hostName):\(port)/uuid")!
		let t = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
			DispatchQueue.main.async {
				if let s = self,
					let d = data,
					let dictionary = (try? JSONSerialization.jsonObject(with: d, options: [])) as? Dictionary<String, Any>,
					let uuidString = dictionary["uuid"] as? String,
					let uuid = UUID(uuidString: uuidString) {
					s.task = nil
					s.uuid = uuid
					completion(s)
				} else if let s = self {
					s.task = nil
					completion(s)
				}
			}
		}
		task = t
		t.resume()
	}
}
