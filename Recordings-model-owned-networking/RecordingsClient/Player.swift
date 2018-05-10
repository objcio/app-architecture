import Foundation
import AVFoundation

let mpegTimescale: Int32 = 90000

class Player: NSObject {
	private let item: AVPlayerItem
	private let audioPlayer: AVPlayer
	private let update: (TimeInterval?) -> ()
	private var timeObserver: Any?
	private var statusObserver: Any?
	private var itemObserver: Any?

	init?(url: URL, update: @escaping (TimeInterval?) -> ()) {
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			return nil
		}

		self.update = update
		self.item = AVPlayerItem(url: url)
		self.audioPlayer = AVPlayer(playerItem: item)
		super.init()
		
		statusObserver = self.item.observe(\.status) { [weak self] object, change in
			guard let s = self else { return }
			switch s.item.status {
			case .failed:
				s.removeTimer()
				s.update(nil)
			case .readyToPlay:
				s.update(s.audioPlayer.currentTime().seconds)
			case .unknown:
				s.update(0)
			}
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
		NotificationCenter.default.addObserver(self, selector: #selector(handleEnd(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: item)
	}
	
	@objc func handleEnd(_ notification: Notification) {
		removeTimer()
		setProgress(0)
		update(notification.name == .AVPlayerItemDidPlayToEndTime ? 0 : nil)
	}
	
	func togglePlay() {
		if audioPlayer.rate > 0 {
			audioPlayer.pause()
			removeTimer()
		} else {
			audioPlayer.play()
			removeTimer()
			timeObserver = audioPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.02, preferredTimescale: mpegTimescale), queue: DispatchQueue.main) { [weak self] _ in
				guard let s = self else { return }
				s.update(s.audioPlayer.currentTime().seconds)
			}
		}
	}
	
	private func removeTimer() {
		if let to = timeObserver {
			audioPlayer.removeTimeObserver(to)
			timeObserver = nil
		}
	}

	func setProgress(_ time: TimeInterval) {
		audioPlayer.seek(to: CMTime(seconds: time, preferredTimescale: mpegTimescale))
	}

	var duration: TimeInterval {
		return item.status == .readyToPlay ? item.duration.seconds : 0
	}
	
	var isPlaying: Bool {
		return audioPlayer.rate > 0
	}
	
	var isPaused: Bool {
		return audioPlayer.rate == 0 && audioPlayer.currentTime().seconds > 0
	}
	
	deinit {
		removeTimer()
	}
}
