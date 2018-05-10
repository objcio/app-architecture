import Foundation
import UIKit
import AVFoundation

private let formatter: DateComponentsFormatter = {
	let formatter = DateComponentsFormatter()
	formatter.unitsStyle = .positional
	formatter.zeroFormattingBehavior = .pad
	formatter.allowedUnits = [.hour, .minute, .second]
	return formatter
}()

func timeString(_ time: TimeInterval) -> String {
	return formatter.string(from: time) ?? ""
}

struct AudioSession {
	static let shared = AudioSession()
	enum AudioSessionError: Error { case recordPermissionDenied }
	let isActive: Signal<Bool>
	init() {
		isActive = Signal<Bool>.retainedGenerate { (input: SignalInput<Bool>?) in
			guard let i = input else {
				_ = try? AVAudioSession.sharedInstance().setActive(false)
				return
			}
			do {
				try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
				try AVAudioSession.sharedInstance().setActive(true)
				AVAudioSession.sharedInstance().requestRecordPermission() { allowed in
					i.send(result: allowed ? .success(true) : .failure(AudioSessionError.recordPermissionDenied))
				}
			} catch {
				i.send(error: error)
			}
		}.continuousWhileActive()
	}
}
