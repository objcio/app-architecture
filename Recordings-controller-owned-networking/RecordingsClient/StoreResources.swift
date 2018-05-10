//
//  Operation.swift
//  RecordingsClient
//
//  Created by Matt Gallagher on 2017/07/15.
//  Copyright © 2017 Matt Gallagher ( http://cocoawithlove.com ). All rights reserved.
//

import Foundation

extension URLSession {
	@discardableResult
	func load<A>(_ resource: Resource<A>, completion: @escaping (Result<A>) -> ()) -> URLSessionDataTask {
		dump(resource.request)
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
