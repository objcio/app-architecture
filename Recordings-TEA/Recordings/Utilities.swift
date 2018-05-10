import Foundation
import UIKit

private let formatter: DateComponentsFormatter = {
	let formatter = DateComponentsFormatter()
	formatter.unitsStyle = .positional
	formatter.zeroFormattingBehavior = .pad
	formatter.allowedUnits = [.hour, .minute, .second]
	return formatter
}()

func timeString(_ time: TimeInterval) -> String {
	return formatter.string(from: time)!
}

extension UIViewController {
	func modalTextAlert(title: String, accept: String = NSLocalizedString("OK", comment: ""), cancel: String = .cancel, placeholder: String, callback: @escaping (String?) -> ()) {
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		alert.addTextField { $0.placeholder = placeholder }
		alert.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in
			callback(nil)
		})
		alert.addAction(UIAlertAction(title: accept, style: .default) { _ in
			callback(alert.textFields?.first?.text)
		})
		let vc = self.presentedViewController ?? self
		vc.present(alert, animated: true)
	}
}

extension String {
	static let cancel = NSLocalizedString("Cancel", comment: "")
}

extension UIColor {
	static var blueTint: UIColor {
		return UIColor(displayP3Red: 0.25053444504737854, green: 0.5637395977973938, blue: 0.83535277843475342, alpha: 1)
	}
	static var orangeTint: UIColor {
		return UIColor(displayP3Red: 0.95211482048034668, green: 0.67795038223266602, blue: 0.33723476529121399, alpha: 1)
	}
}

#if !swift(>=4.1)
	extension Array {
		public func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
			return try flatMap(transform)
		}
	}
#endif
