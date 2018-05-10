import Foundation

enum Result<A> {
	case error(Error)
	case success(A)
	
	init(_ value: A?, or: @autoclosure () -> Error) {
		if let x = value { self = .success(x) }
		else { self = .error(or()) }
	}
	
	func map<B>(_ f: (A) -> B) -> Result<B> {
		switch self {
		case .error(let e): return .error(e)
		case .success(let x): return .success(f(x))
		}
	}
	
	func flatMap<B>(_ f: (A) -> Result<B>) -> Result<B> {
		switch self {
		case .error(let e): return .error(e)
		case .success(let x): return f(x)
		}
	}
	
	func flatMap<B>(_ f: (A) -> B?, or e: Error) -> Result<B> {
		switch self {
		case .error(let e): return .error(e)
		case .success(let x):
			if let value = f(x) { return .success(value) }
			return .error(e)
		}
	}
}
