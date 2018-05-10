import Cocoa
import AVFoundation

final class RecordViewController: NSViewController, AVAudioRecorderDelegate {
	@IBOutlet var timeLabel: NSTextField!
	@IBOutlet var stopButton: NSButton!
	
	var audioRecorder: Recorder?
	var folder: Folder? = nil
	var recording = Recording(name: "", uuid: UUID())
	
	override func viewDidLoad() {
		super.viewDidLoad()
		timeLabel.stringValue = timeString(0)
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		audioRecorder = Recorder(url: Store.shared.fileURL(for: recording)) { time in
			if let t = time {
				self.timeLabel.stringValue = timeString(t)
			} else {
				self.dismiss(self)
			}
		}
		if audioRecorder == nil {
			self.dismiss(self)
		}
	}
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		if segue.identifier == .newRecordingName, let newItemViewController = segue.destinationController as? NewItemViewController {
			newItemViewController.parentFolder = folder ?? Store.shared.rootFolder
			newItemViewController.recording = recording
		}
	}

	@IBAction func stop(_ sender: Any) {
		audioRecorder?.stop()
		self.performSegue(withIdentifier: .newRecordingName, sender: self)
	}
}

fileprivate extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}

fileprivate extension NSStoryboardSegue.Identifier {
	static let newRecordingName = NSStoryboardSegue.Identifier("newRecordingName")
}
