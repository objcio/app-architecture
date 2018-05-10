import Foundation

struct Resource<A> {
	var method: String = "GET"
	var body: Data? = nil
	let url: URL
	
	let parseResult: (Data) -> Result<A>
}

struct ParseError: Error {}

extension Resource {
	init(url: URL, postJSON json: Any?, parse: @escaping (Any) -> A?) {
		self.url = url
		self.method = "POST"
		self.body = json.map { try! JSONSerialization.data(withJSONObject: $0, options: []) }
		self.parseResult = { data in
			let json = try? JSONSerialization.jsonObject(with: data, options: [])
			return Result(json.flatMap(parse), or: ParseError())
		}
	}
	
	init(url: URL, postJSON json: Any?, parse: @escaping (Any) -> Result<A>) {
		self.url = url
		self.method = "POST"
		self.body = json.map { try! JSONSerialization.data(withJSONObject: $0, options: []) }
		self.parseResult = { data in
			let json = try? JSONSerialization.jsonObject(with: data, options: [])
			return json.flatMap(parse)  ?? .error(ParseError())
		}
	}
	
	init(url: URL, parseJSON parse: @escaping (Any) -> A?) {
		self.url = url
		self.parseResult = { data in
			let json = try? JSONSerialization.jsonObject(with: data, options: [])
			return Result(json.flatMap(parse), or: ParseError())
		}
	}
	
	init(url: URL, parseJSON parse: @escaping (Any) -> Result<A>) {
		self.url = url
		self.parseResult = { data in
			let json = try? JSONSerialization.jsonObject(with: data, options: [])
			return json.flatMap(parse) ?? .error(ParseError())
		}
	}
}

extension Resource where A: RangeReplaceableCollection {
	init(url: URL, parseElementJSON parse: @escaping (Any) -> A.Element?) {
		self.url = url
		self.parseResult = { data in
			guard
				let json = try? JSONSerialization.jsonObject(with: data, options: []),
				let jsonArray = json as? [Any]
				else { return .error(ParseError()) }
			let items = jsonArray.compactMap(parse)
			guard jsonArray.count == items.count else { return .error(ParseError()) }
			return .success(A(items))
		}
	}
}

extension Resource {
	var request: URLRequest {
		var result = URLRequest(url: url)
		result.httpMethod = method
		if method == "POST" {
			result.httpBody = body
		}
		return result
	}
}

extension URLSession {
	@discardableResult
	func load<A>(_ resource: Resource<A>, completion: @escaping (Result<A>) -> ()) -> URLSessionDataTask {
		let t = dataTask(with: resource.request) { (data, response, error) in
			DispatchQueue.main.async {
				if let e = error {
					completion(.error(e))
				} else if let d = data {
					completion(resource.parseResult(d))
				}
			}
		}
		t.resume()
		return t
	}
}
