import UIKit

extension UIColor {
	static var blueTint: UIColor {
		return UIColor(displayP3Red: 0.251, green: 0.564, blue: 0.835, alpha: 1)
	}
	static var orangeTint: UIColor {
		return UIColor(displayP3Red: 0.952, green: 0.678, blue: 0.337, alpha: 1)
	}
}

extension Button {
	convenience init(recordingsAppButtonBindings: Button.Binding...) {
		self.init(bindings: Button(
			.titleColor -- .normal(.white),
			.titleLabel -- Label(.font -- .preferredFont(forTextStyle: .headline)),
			.backgroundColor -- .orangeTint,
			.layer -- BackingLayer(.cornerRadius -- 4)
		).consumeBindings() + recordingsAppButtonBindings)
	}
}

