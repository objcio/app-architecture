import UIKit
import AVFoundation

final class RecordViewController: UIViewController, AVAudioRecorderDelegate {
	@IBOutlet var timeLabel: UILabel!
	@IBOutlet var stopButton: UIButton!
    
	var audioRecorder: Recorder?
	var folder: Folder? = nil
	var recording = Recording(name: "", uuid: UUID())
	
	override func viewDidLoad() {
		super.viewDidLoad()
		timeLabel.text = timeString(0)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		audioRecorder = folder?.store?.fileURL(for: recording).flatMap { url in
			Recorder(url: url) { time in
				if let t = time {
					self.timeLabel.text = timeString(t)
				} else {
					self.dismiss(animated: true)
				}
			}
		}
		if audioRecorder == nil {
			dismiss(animated: true)
		}
	}
	
	@IBAction func stop(_ sender: Any) {
		audioRecorder?.stop()
		modalTextAlert(title: .saveRecording, accept: .save, placeholder: .nameForRecording) { string in
			if let title = string {
				self.recording.setName(title)
				self.folder?.add(self.recording)
			} else {
				self.recording.deleted()
			}
			self.dismiss(animated: true)
		}
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}
