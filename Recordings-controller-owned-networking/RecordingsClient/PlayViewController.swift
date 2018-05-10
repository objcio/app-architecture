import UIKit
import AVFoundation

class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateForChangedRecording()
		}
	}
	var store: Server!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		updateForChangedRecording()
	}

	func updateForChangedRecording() {
		if let r = recording {
			let streamUrl: URL = store.streamUrl(for: r.uuid)
			audioPlayer = Player(url: streamUrl) { [weak self] time in
				if let t = time {
					self?.updateProgressDisplays(progress: t, duration: self?.audioPlayer?.duration ?? 0)
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				updateProgressDisplays(progress: 0, duration: ap.duration)
				navigationItem.title = r.name
				nameTextField?.text = r.name
				activeItemElements?.isHidden = false
				noRecordingLabel?.isHidden = true
			} else {
				recording = nil
			}
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			audioPlayer = nil
			navigationItem.title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.text = timeString(progress)
		durationLabel?.text = timeString(duration)
		progressSlider?.maximumValue = Float(duration)
		progressSlider?.value = Float(progress)
		updatePlayButton()
	}
	
	func updatePlayButton() {
		if audioPlayer?.isPlaying == true {
			playButton?.setTitle(.pause, for: .normal)
		} else if audioPlayer?.isPaused == true {
			playButton?.setTitle(.resume, for: .normal)
		} else {
			playButton?.setTitle(.play, for: .normal)
		}
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		if var r = recording, let text = textField.text {
			r.name = text
			URLSession.shared.load(store.change(.update, item: .recording(r))) { result in
				print(result)
			}
			navigationItem.title = r.name
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		audioPlayer?.setProgress(TimeInterval(s.value))
	}
	
	@IBAction func play() {
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
		coder.encode(recording?.uuidPath.map { $0.uuidString }, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
//		if let nc = splitViewController?.viewControllers.first as? UINavigationController, nc.viewControllers.count > 1, let store = (nc.viewControllers[1] as? FolderViewController)?.store, let uuidPath = (coder.decodeObject(forKey: .uuidPathKey) as? [String])?.flatMap({ UUID(uuidString: $0) }), case let .right(recording) = store.item(atUUIDPath: uuidPath) {
//			self.recording = recording
//		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
