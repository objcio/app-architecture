import Foundation
import RxSwift
import RxCocoa
import AVFoundation

class PlayViewModel {
	let recording: Variable<Recording?> = Variable(nil)
	let playState: Observable<Player.State?>
	let togglePlay = PublishSubject<()>()
	let setProgress = PublishSubject<TimeInterval>()
	

	private let recordingUntilDeleted: Observable<Recording?>
	
	init() {
		recordingUntilDeleted = recording.asObservable()
			// Every time the folder changes
			.flatMapLatest { recording -> Observable<Recording?> in
				guard let currentRecording = recording else { return Observable.just(nil) }
				// Start by emitting the current recording
				return Observable.just(currentRecording)
				// Re-emit the recording every time a non-delete change occurs
				.concat(currentRecording.changeObservable.map { _ in currentRecording })
				// Stop when a delete occurs
				.takeUntil(currentRecording.deletedObservable)
				// After a delete, set the current recording back to `nil`
				.concat(Observable.just(nil))
			}.share(replay: 1)
		playState = recordingUntilDeleted.flatMapLatest { [togglePlay, setProgress] recording throws -> Observable<Player.State?> in
			guard let r = recording else {
				return Observable<Player.State?>.just(nil)
			}
			return Observable<Player.State?>.create { (o: AnyObserver<Player.State?>) -> Disposable in
				guard let url = r.fileURL, let p = Player(url: url, update: { playState in
					o.onNext(playState)
				}) else {
					o.onNext(nil)
					return Disposables.create {}
				}
				o.onNext(p.state)
				let disposables = [
					togglePlay.subscribe(onNext: {
						p.togglePlay()
					}),
					setProgress.subscribe(onNext: { progress in
						p.setProgress(progress)
					})
				]
				return Disposables.create {
					p.cancel()
					disposables.forEach { $0.dispose() }
				}
			}
		}.share(replay: 1)
	}
	
	func nameChanged(_ name: String?) {
		guard let r = recording.value, let text = name else { return }
		r.setName(text)
	}
	
	var navigationTitle: Observable<String> {
		return recordingUntilDeleted.map { $0?.name ?? "" }
	}
	var hasRecording: Observable<Bool> {
		return recordingUntilDeleted.map { $0 != nil }
	}
	var noRecording: Observable<Bool> {
		return hasRecording.map { !$0 }.delay(0, scheduler: MainScheduler())
	}
	var timeLabelText: Observable<String?> {
		return progress.map { $0.map(timeString) }
	}
	var durationLabelText: Observable<String?> {
		return playState.map { $0.map { timeString($0.duration) } }
	}
	var sliderDuration: Observable<Float> {
		return playState.map { $0.flatMap { Float($0.duration) } ?? 1.0 }
	}
	var sliderProgress: Observable<Float> {
		return playState.map { $0.flatMap { Float($0.currentTime) } ?? 0.0 }
	}
	var progress: Observable<TimeInterval?> {
		return playState.map { $0?.currentTime }
	}
	var isPaused: Observable<Bool> {
		return playState.map { $0?.activity == .paused }
	}
	var isPlaying: Observable<Bool> {
		return playState.map { $0?.activity == .playing }
	}
	var nameText: Observable<String?> {
		return recordingUntilDeleted.map { $0?.name }
	}
	var playButtonTitle: Observable<String> {
		return playState.map { s in
			switch s?.activity {
			case .playing?: return .pause
			case .paused?: return .resume
			default: return .play
			}
		}
	}
}

fileprivate extension String {
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
