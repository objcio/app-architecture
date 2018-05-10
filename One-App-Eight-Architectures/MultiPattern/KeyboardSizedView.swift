import UIKit

class KeyboardSizedView: UIView {
	var keyboardConstraint: NSLayoutConstraint? = nil

	override func didMoveToSuperview() {
		if superview != nil {
			NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
		} else {
			NotificationCenter.default.removeObserver(self)
		}
	}

	@objc func keyboardChanged(_ notification: Notification) {
		let rect: CGRect
		if notification.name == NSNotification.Name.UIKeyboardWillShow {
			rect = convert((notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue, from: nil)
		} else {
			rect = CGRect.zero
		}
		keyboardConstraint?.isActive = false
		keyboardConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: rect.size.height)
		keyboardConstraint?.isActive = true
		UIView.beginAnimations("keyboardResize", context: nil)
		superview?.layoutIfNeeded()
		UIView.commitAnimations()
	}
}
