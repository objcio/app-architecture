import Cocoa
import AVFoundation

class PlayViewController: NSViewController, AVAudioPlayerDelegate, NSTextFieldDelegate {
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var playButton: NSButton!
	@IBOutlet var progressLabel: NSTextField!
	@IBOutlet var durationLabel: NSTextField!
	@IBOutlet var progressSlider: NSSlider!
	@IBOutlet var recordingTitle: NSTextField!
	@IBOutlet var activeItemElements: NSView!
	
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateForChangedRecording()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		updateForChangedRecording()
		
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSControl.textDidChangeNotification, object: nameTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()

		if let windowController = self.view.window?.delegate as? WindowController {
			windowController.playViewController = self
		}
	}
	
	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateForChangedRecording()
	}
	
	func updateForChangedRecording() {
		if let r = recording {
			audioPlayer = Player(url: Store.shared.fileURL(for: r)) { [weak self] time in
				if let t = time {
					self?.updateProgressDisplays(progress: t, duration: self?.audioPlayer?.duration ?? 0)
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				updateProgressDisplays(progress: 0, duration: ap.duration)
				nameTextField?.stringValue = r.name
				activeItemElements?.isHidden = false
				recordingTitle?.stringValue = r.name
				recordingTitle.textColor = .darkGray
			} else {
				recording = nil
			}
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			audioPlayer = nil
			activeItemElements?.isHidden = true
			recordingTitle.stringValue = .noRecording
			recordingTitle.textColor = .gray
		}
	}
	
	func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.stringValue = timeString(progress)
		durationLabel?.stringValue = timeString(duration)
		progressSlider?.maxValue = duration
		progressSlider?.doubleValue = progress
		updatePlayButton()
	}
	
	func updatePlayButton() {
		if audioPlayer?.isPlaying == true {
			playButton?.title = .pause
		} else if audioPlayer?.isPaused == true {
			playButton?.title = .resume
		} else {
			playButton?.title = .play
		}
	}
	
	@objc func textDidChange(_ notification: Notification) {
		if !nameTextField.stringValue.isEmpty, let r = recording {
			r.setName(nameTextField.stringValue)
		}
	}

	func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
		if nameTextField.stringValue.isEmpty {
			return false
		}
		self.textDidChange(Notification(name: NSControl.textDidChangeNotification))
		return true
	}
	
	@IBAction func setProgress(_ sender: Any?) {
		guard let s = progressSlider else { return }
		audioPlayer?.setProgress(TimeInterval(s.doubleValue))
	}
	
	@IBAction func play(_ sender: Any?) {
		audioPlayer?.togglePlay()
		updatePlayButton()
	}
}

fileprivate extension String {
	static let noRecording = NSLocalizedString("No recording selected.", comment: "")
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}

