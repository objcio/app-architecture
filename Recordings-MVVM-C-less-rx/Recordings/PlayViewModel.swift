import Foundation
import AVFoundation

class PlayViewModel: NSObject {
	@objc dynamic var navigationTitle: String? = ""
	@objc dynamic var hasRecording = false
	@objc dynamic var noRecording = true
	@objc dynamic var timeLabelText: String? = nil
	@objc dynamic var durationLabelText: String? = nil
	@objc dynamic var sliderDuration: Float = 1.0
	@objc dynamic var sliderProgress: Float = 0.0
	@objc dynamic var progress: NSNumber? = nil
	@objc dynamic var isPaused = false
	@objc dynamic var isPlaying = false
	@objc dynamic var nameText: String? = nil
	@objc dynamic var playButtonTitle = String.play
	
	var recording: Recording? = nil {
		didSet {
			guard recording !== oldValue else { return }
			updateForChangedRecording()
		}
	}

	private var audioPlayer: Player?

	override init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		if notification.userInfo?[Item.changeReasonKey] as? String == Item.removed {
			recording = nil
		}
		updateForChangedRecording()
	}
	
	private func updateForChangedRecording() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] state in
				if state != nil {
					self?.updateProgressDisplays(progress: state?.currentTime, duration: state?.duration)
				} else {
					self?.recording = nil
				}
			}

			if let ap = audioPlayer {
				updateProgressDisplays(progress: 0, duration: ap.duration)
				navigationTitle = r.name
				nameText = r.name
				hasRecording = true
				noRecording = false
			} else {
				recording = nil
			}
		} else {
			audioPlayer = nil
			updateProgressDisplays(progress: 0, duration: 0)
			navigationTitle = ""
			noRecording = true
			hasRecording = false
		}
	}

	func updateProgressDisplays(progress: TimeInterval?, duration: TimeInterval?) {
		timeLabelText = timeString(progress ?? 0)
		durationLabelText = timeString(duration ?? 0)
		sliderDuration = Float(duration ?? 0)
		sliderProgress = Float(progress ?? 0)
		updatePlayButton()
	}
	
	func updatePlayButton() {
		if audioPlayer?.activity == .playing {
			playButtonTitle = .pause
		} else if audioPlayer?.activity == .paused {
			playButtonTitle = .resume
		} else {
			playButtonTitle = .play
		}
	}

	func togglePlay() {
		audioPlayer?.togglePlay()
		updatePlayButton()
	}
	
	func setProgress(_ progress: TimeInterval) {
		audioPlayer?.setProgress(progress)
		updateProgressDisplays(progress: progress, duration: audioPlayer?.duration ?? 0)
	}

	func nameChanged(_ name: String?) {
		guard let r = recording, let text = name else { return }
		r.setName(text)
	}
}

fileprivate extension Player.Activity {
	var displayTitle: String {
		switch self {
		case .playing: return .pause
		case .paused: return .resume
		case .stopped: return .play
		}
	}
}

fileprivate extension String {
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
