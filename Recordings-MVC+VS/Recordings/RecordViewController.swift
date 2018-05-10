import UIKit
import AVFoundation

final class RecordViewController: UIViewController, AVAudioRecorderDelegate {
	var context: StoreContext! { willSet { precondition(!isViewLoaded) } }

	@IBOutlet var timeLabel: UILabel!
   @IBOutlet var stopButton: UIButton!
	
	let recordingUUID = UUID()
	var observations = Observations()
	var state: RecordViewState?

	var audioRecorder: Recorder?
	var needsFileDeleted = true
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		observations += context.viewStateStore.addObserver(actionType: RecordViewState.Action.self) { [unowned self] (state, action) in
			guard let rvs = state.recordView else { return }
			self.state = rvs
			self.handleViewStateNotification(action)
		}
	}
	
	func handleViewStateNotification(_ action: RecordViewState.Action?) {
		guard let recordState = state?.recordState else { return }
		if !recordState.ended {
			self.timeLabel.text = timeString(recordState.duration)
		} else {
			context.viewStateStore.dismissRecording()
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		if needsFileDeleted, let url = context.documentStore.fileURL(for: recordingUUID) {
			_ = try? FileManager.default.removeItem(at: url)
			needsFileDeleted = false
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		guard let url = context.documentStore.fileURL(for: recordingUUID) else {
			context.viewStateStore.dismissRecording()
			return
		}
		
		audioRecorder = Recorder(url: url) { [context] recordState in
			context!.viewStateStore.updateRecordState(recordState)
		}
		needsFileDeleted = true
		
		if audioRecorder == nil {
			context.viewStateStore.dismissRecording()
		}
	}
	
	@IBAction func stop(_ sender: Any) {
		audioRecorder?.stop()
		if let parentUUID = state?.parentUUID {
			needsFileDeleted = false
			context.viewStateStore.dismissRecording()
			context.viewStateStore.showSaveRecording(uuid: recordingUUID, parentUUID: parentUUID)
		} else {
			context.viewStateStore.dismissRecording()
		}
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}
