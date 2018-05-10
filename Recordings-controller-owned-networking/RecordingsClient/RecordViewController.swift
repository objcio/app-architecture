import UIKit
import AVFoundation

protocol RecordViewControllerDelegate: class {
	func recordingAdded(_ result: Result<Recording>)
}


final class RecordViewController: UIViewController, AVAudioRecorderDelegate {
	@IBOutlet var timeLabel: UILabel!
	@IBOutlet var stopButton: UIButton!
    
	var audioRecorder: Recorder?
	var folder: Folder!
	var store: Server!
	weak var delegate: RecordViewControllerDelegate?
	var tempFile: TempFile?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		timeLabel.text = timeString(0)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		tempFile = TempFile(extension: ".m4a")
		audioRecorder = Recorder(url: tempFile!.url) { time in
			if let t = time {
				self.timeLabel.text = timeString(t)
			} else {
				self.dismiss(animated: true)
			}
		}
		if audioRecorder == nil {
			dismiss(animated: true)
		}
	}
	
	@IBAction func stop(_ sender: Any) {
		audioRecorder?.stop()
		modalTextAlert(title: .saveRecording, accept: .save, placeholder: .nameForRecording) { string in
			if let title = string, let file = self.tempFile {
				URLSession.shared.load(self.store.upload(name: title, folder: self.folder, file: file)) { result in
					_ = self.delegate?.recordingAdded(result)
					
				}
			}
			self.tempFile = nil
         self.dismiss(animated: true)
		}
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}
