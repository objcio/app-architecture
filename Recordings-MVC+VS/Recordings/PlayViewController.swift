import UIKit
import AVFoundation

class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	var context: StoreContext! { willSet { precondition(!isViewLoaded) } }

	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	var observations = Observations()
	var state: PlayViewState = PlayViewState(uuid: nil)
	var audioPlayer: Player? = nil
	var recording: Recording?
	
	init() {
		super.init(nibName: nil, bundle: nil)
		updateNavigationItemTitle()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		updateNavigationItemTitle()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true

		NotificationCenter.default.addObserver(self, selector: #selector(textChanged(_:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nameTextField)

		observations += context.viewStateStore.addObserver(actionType: PlayViewState.Action.self) { [unowned self] (state, action) in
			self.state = state.playView
			self.handleViewStateNotification(action)
		}
		observations += context.documentStore.addObserver(actionType: DocumentStore.Action.self) { [unowned self] store, action in
			self.recording = self.state.uuid.flatMap { self.context.documentStore.content[$0]?.recording }
			self.handleStoreNotification(action)
		}
	}
	
	func updateNavigationItemTitle() {
		if let r = recording {
			navigationItem.title = r.name
		} else {
			navigationItem.title = ""
		}
	}
	
	func updatePlayState(_ playState: PlayState) {
		progressLabel?.text = timeString(playState.progress)
		durationLabel?.text = timeString(playState.duration)
		progressSlider?.maximumValue = Float(playState.duration)
		progressSlider?.value = Float(playState.progress)
		playButton?.setTitle(playState.isPlaying ? .pause : (playState.progress > 0 ? .resume : .play), for: .normal)
	}

	func handleViewStateNotification(_ action: PlayViewState.Action?) {
		switch action {
		case .updatePlayState?:
			if let playState = state.playState {
				updatePlayState(playState)
			}
		case .changePlaybackPosition?:
			if let playState = state.playState {
				audioPlayer?.setProgress(playState.progress)
			}
		case .togglePlay?:
			if let playState = state.playState {
				updatePlayState(playState)
			}
			audioPlayer?.togglePlay()
		case nil:
			if let uuid = state.uuid, let url = context.documentStore.fileURL(for: uuid) {
				audioPlayer = Player(url: url, initialProgress: state.playState?.progress) { [context] playState in
					context!.viewStateStore.updatePlayState(playState)
				}
				if audioPlayer != nil {
					if let playState = state.playState {
						audioPlayer?.setProgress(playState.progress)
					}
					activeItemElements?.isHidden = false
					noRecordingLabel?.isHidden = true
				} else {
					activeItemElements?.isHidden = true
					noRecordingLabel?.isHidden = false
				}
			} else {
				audioPlayer = nil
				activeItemElements?.isHidden = true
				noRecordingLabel?.isHidden = false
			}
		}
	}

	func handleStoreNotification(_ action: DocumentStore.Action?) {
		switch action {
		case .removed(_, let childUUID, _)? where childUUID == state.uuid:
			// Item deleted... remove from ViewState
			context.viewStateStore.setPlaySelection(nil, alreadyApplied: false)
		case .removed?: break
		case .renamed(_, let childUUID, _, _)? where childUUID == state.uuid:
			// This item changed, update
			navigationItem.title = recording?.name
			nameTextField?.text = recording?.name
		case .renamed?: break
		case .added?: break
		case nil:
			if state.uuid != nil, recording == nil {
				// Item deleted... remove from ViewState
				context.viewStateStore.setPlaySelection(nil, alreadyApplied: false)
				return
			}
			
			// Store reloaded, refresh everything
			updateNavigationItemTitle()
			if let r = recording {
				nameTextField?.text = r.name
			} else {
				navigationItem.title = ""
			}
		}
	}
	
	@objc func textChanged(_ notification: Notification) {
		guard let r = recording, let text = nameTextField.text else { return }
		context.documentStore.renameItem(uuid: r.uuid, newName: text)
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		context.viewStateStore.changePlaybackPosition(TimeInterval(s.value))
	}
	
	@IBAction func play() {
		context.viewStateStore.togglePlay()
	}
}

fileprivate extension String {
	static let uuidKey = "uuid"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
