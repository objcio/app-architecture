import UIKit

extension NSObjectProtocol where Self: NSObject {
	func observe<Value>(_ keyPath: KeyPath<Self, Value>, onChange: @escaping (Value) -> ()) -> NSKeyValueObservation {
		return observe(keyPath, options: [.initial, .new]) { _, change in
			// TODO: change.newValue should never be `nil`, but when observing an optional property that's set to `nil`, then change.newValue is `nil` instead of `Optional(nil)`. This is the bug report for this: https://bugs.swift.org/browse/SR-6066
			guard let newValue = change.newValue else { return }
			onChange(newValue)
		}
	}

	func bind<Value, Target>(_ sourceKeyPath: KeyPath<Self, Value>, to target: Target, at targetKeyPath: ReferenceWritableKeyPath<Target, Value>) -> NSKeyValueObservation {
		return observe(sourceKeyPath) { target[keyPath: targetKeyPath] = $0 }
	}
}

class PlayViewController: UIViewController, UITextFieldDelegate {
	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	let viewModel = PlayViewModel()

	var observations: [NSKeyValueObservation] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		observations = [
			viewModel.bind(\.navigationTitle, to: navigationItem, at: \.title),
			viewModel.bind(\.hasRecording, to: noRecordingLabel, at: \.isHidden),
			viewModel.bind(\.noRecording, to: activeItemElements, at: \.isHidden),
			viewModel.bind(\.timeLabelText, to: progressLabel, at: \.text),
			viewModel.bind(\.durationLabelText, to: durationLabel, at: \.text),
			viewModel.bind(\.sliderDuration, to: progressSlider, at: \.maximumValue),
			viewModel.bind(\.sliderProgress, to: progressSlider, at: \.value),
			viewModel.observe(\.playButtonTitle) { [playButton] in playButton!.setTitle($0, for: .normal) },
			viewModel.bind(\.nameText, to: nameTextField, at: \.text)
		]
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		viewModel.nameChanged(textField.text)
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		viewModel.setProgress(TimeInterval(s.value))
	}
	
	@IBAction func play() {
		viewModel.togglePlay()
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(viewModel.recording?.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let recording = Store.shared.item(atUUIDPath: uuidPath) as? Recording {
			self.viewModel.recording? = recording
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
}
