import Foundation
import AVFoundation

struct RecordState: Codable {
	let duration: TimeInterval
	let ended: Bool
	
	init(duration: TimeInterval = 0, ended: Bool = false) {
		self.duration = duration
		self.ended = ended
	}
}

final class Recorder: NSObject, AVAudioRecorderDelegate {
	private var audioRecorder: AVAudioRecorder?
	private var timer: Timer?
	private var update: (RecordState) -> ()
	let url: URL
	
	init?(url: URL, update: @escaping (RecordState) -> ()) {
		self.update = update
		self.url = url
		
		super.init()
		
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
			try AVAudioSession.sharedInstance().setActive(true)
			AVAudioSession.sharedInstance().requestRecordPermission() { [weak self] allowed in
				guard let s = self else { return }
				if allowed {
					s.start(url)
				} else {
					s.update(s.recordState)
				}
			}
		} catch {
			return nil
		}
	}
	
	var recordState: RecordState {
		return RecordState(duration: audioRecorder?.currentTime ?? 0, ended: !(audioRecorder?.isRecording ?? true))
	}
	
	private func start(_ url: URL) {
		let settings: [String: Any] = [
			AVFormatIDKey: kAudioFormatMPEG4AAC,
			AVSampleRateKey: 44100.0 as Float,
			AVNumberOfChannelsKey: 1
		]
		if let recorder = try? AVAudioRecorder(url: url, settings: settings) {
			recorder.delegate = self
			audioRecorder = recorder
			recorder.record()
			timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
				guard let s = self else { return }
				s.update(s.recordState)
			}
		} else {
			update(recordState)
		}
	}
	
	func stop() {
		audioRecorder?.stop()
		timer?.invalidate()
	}
	
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		if flag {
			stop()
		} else {
			update(recordState)
		}
	}
}
