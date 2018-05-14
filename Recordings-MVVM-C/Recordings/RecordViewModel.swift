import Foundation
import RxSwift

final class RecordViewModel {
	// Inputs
	var folder: Folder? = nil
	let recording = Recording(name: "", uuid: UUID())
	let duration = Variable<TimeInterval>(0)
	
	// Actions
	func recordingStopped(title: String?) {
		guard let title = title else {
			recording.deleted()
			return
		}
		recording.setName(title)
		folder?.add(recording)
	}
	
	func recorderStateChanged(time: TimeInterval?) {
		if let t = time {
			duration.value = t
		} else {
			dismiss?()
		}

	}
	
	// Outputs
	var timeLabelText: Observable<String?> {
		return duration.asObservable().map(timeString)
	}
	
	var dismiss: (() -> ())?
}
