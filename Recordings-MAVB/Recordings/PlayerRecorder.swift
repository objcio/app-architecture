import Foundation
import AVFoundation

enum PlayerRecorderControl {
	case setProgress(TimeInterval)
	case togglePlay
	case audioSessionActive(Bool)
	case stop
}

struct PlayerRecorderState: Codable {
	let progress: TimeInterval
	let duration: TimeInterval
	let active: Bool
}

protocol PlayerRecorder: class {
	func start()
	func pause()
	func stop()
	var progress: TimeInterval { get set }
	var duration: TimeInterval { get }
	var playRecordDelegate: NSObjectProtocol? { get set }
}

extension AVAudioPlayer: PlayerRecorder {
	func start() { play() }
	var progress: TimeInterval {
		get { return currentTime }
		set { currentTime = newValue }
	}
	var playRecordDelegate: NSObjectProtocol? {
		get { return delegate }
		set { delegate = newValue as? AVAudioPlayerDelegate }
	}
}

extension AVAudioRecorder: PlayerRecorder {
	func start() { record() }
	var duration: TimeInterval { return currentTime }
	var progress: TimeInterval {
		get { return currentTime }
		set { }
	}
	var playRecordDelegate: NSObjectProtocol? {
		get { return delegate }
		set { delegate = newValue as? AVAudioRecorderDelegate }
	}
}

class PlayerRecorderStorage: NSObject, Cancellable, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
	var sessionActive: Bool = false
	var playRecordActive: Bool
	var timerReconnector: SignalReconnector<Int>
	var outputCancellable: Cancellable? = nil
	var delegateInput: SignalInput<()>
	let playRecord: PlayerRecorder
	
	init(playRecord: PlayerRecorder, input controlInput: Signal<PlayerRecorderControl>, output: SignalInput<PlayerRecorderState>, startImmediately: Bool = false) {
		self.playRecord = playRecord
		self.playRecordActive = startImmediately
		
		let timerSignal: Signal<Int>
		(timerReconnector, timerSignal) = Signal.interval(.milliseconds(50)).reconnector()

		let delegateSignal: Signal<()>
		(delegateInput, delegateSignal) = Signal<()>.create()

		super.init()
		
		outputCancellable = controlInput
			.combineValues(delegateSignal, timerSignal)
			.compactMap(context: .main) { [weak self] in self?.updateAndEmitState(value: $0) }
			.startWith(PlayerRecorderState(progress: 0, duration: playRecord.duration, active: false))
			.cancellableBind(to: output)
		
		playRecord.playRecordDelegate = self
	}
	
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		delegateInput.send(result: flag ? .success(()) : .failure(SignalComplete.cancelled))
	}
	
	func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		if let e = error {
			delegateInput.send(error: e)
		}
	}
	
	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		if flag {
			delegateInput.send(value: ())
		} else {
			delegateInput.cancel()
		}
	}
	
	func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
		if let e = error {
			delegateInput.send(error: e)
		}
	}
	
	func updateAndEmitState(value: EitherValue3<PlayerRecorderControl, (), Int>) -> PlayerRecorderState {
		switch value {
		case .value1(let control):
			let wasActive = playRecordActive && sessionActive
			switch control {
			case .stop: self.cancel()
			case .audioSessionActive(let a): sessionActive = a
			case .togglePlay: playRecordActive = !playRecordActive
			case .setProgress(let ti): playRecord.progress = ti
			}
			if (playRecordActive && sessionActive) && !wasActive {
				playRecord.start()
				timerReconnector.reconnect()
			} else if !(playRecordActive && sessionActive) && wasActive {
				timerReconnector.disconnect()
				playRecord.pause()
			}
		case .value2:
			playRecordActive = false
			timerReconnector.disconnect()
		case .value3: break
		}
		return PlayerRecorderState(progress: playRecord.progress, duration: playRecord.duration, active: sessionActive && playRecordActive)
	}
	
	func cancel() {
		playRecord.playRecordDelegate = nil
		playRecord.stop()
		timerReconnector.cancel()
		outputCancellable?.cancel()
	}
}

struct AudioPlayer: Cancellable {
	private var state: PlayerRecorderStorage?
	init(url: URL, input: Signal<PlayerRecorderControl>, output: SignalInput<PlayerRecorderState>) {
		do {
			let p = try AVAudioPlayer(contentsOf: url)
			state = PlayerRecorderStorage(playRecord: p, input: input, output: output)
		} catch {
			state = nil
			output.send(error: error)
		}
	}
	
	mutating func cancel() {
		state?.cancel()
	}
}

struct AudioRecorder: Cancellable {
	private var state: PlayerRecorderStorage?
	init(url: URL, input: Signal<PlayerRecorderControl>, output: SignalInput<PlayerRecorderState>) {
		do {
			let r = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100.0 as Float, AVNumberOfChannelsKey: 1])
			state = PlayerRecorderStorage(playRecord: r, input: input, output: output, startImmediately: true)
		} catch {
			state = nil
			output.send(error: error)
		}
	}
	
	mutating func cancel() {
		state?.cancel()
	}
}
