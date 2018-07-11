import UIKit
import AVFoundation

class PlayViewController: UIViewController {
	@IBOutlet private var nameTextField: UITextField!
	@IBOutlet private var playButton: UIButton!
	@IBOutlet private var progressLabel: UILabel!
	@IBOutlet private var durationLabel: UILabel!
	@IBOutlet private var progressSlider: UISlider!
	@IBOutlet private var noRecordingLabel: UILabel!
	@IBOutlet private var activeItemElements: UIView!
	
	private var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateForChangedRecording()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		updateForChangedRecording()

		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
	}

	@objc private func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateForChangedRecording()
	}
	
	private func updateForChangedRecording() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] time in
				if let t = time {
					self?.updateProgressDisplays(progress: t, duration: self?.audioPlayer?.duration ?? 0)
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				updateProgressDisplays(progress: 0, duration: ap.duration)
				title = r.name
				nameTextField?.text = r.name
				activeItemElements?.isHidden = false
				noRecordingLabel?.isHidden = true
			} else {
				recording = nil
			}
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			audioPlayer = nil
			title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	private func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.text = timeString(progress)
		durationLabel?.text = timeString(duration)
		progressSlider?.maximumValue = Float(duration)
		progressSlider?.value = Float(progress)
		updatePlayButton()
	}
	
	private func updatePlayButton() {
		if audioPlayer?.isPlaying == true {
			playButton?.setTitle(.pause, for: .normal)
		} else if audioPlayer?.isPaused == true {
			playButton?.setTitle(.resume, for: .normal)
		} else {
			playButton?.setTitle(.play, for: .normal)
		}
	}
	
	@IBAction private func setProgress() {
		guard let s = progressSlider else { return }
		audioPlayer?.setProgress(TimeInterval(s.value))
	}
	
	@IBAction private func play() {
		audioPlayer?.togglePlay()
		updatePlayButton()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		recording = nil
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(recording?.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let recording = Store.shared.item(atUUIDPath: uuidPath) as? Recording {
			self.recording = recording
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

}

extension PlayViewController: UITextFieldDelegate {

	func textFieldDidEndEditing(_ textField: UITextField) {
		if let r = recording, let text = textField.text {
			r.setName(text)
			title = r.name
		}
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
