import Foundation
import AVFoundation

struct PlayState: Codable {
	var isPlaying: Bool
	var progress: TimeInterval
	var duration: TimeInterval
}

class Player: NSObject, AVAudioPlayerDelegate {
	private var audioPlayer: AVAudioPlayer
	private var timer: Timer?
	private var update: (PlayState) -> ()
	
	init?(url: URL, initialProgress: TimeInterval? = nil, update: @escaping (PlayState) -> ()) {
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			return nil
		}

		if let player = try? AVAudioPlayer(contentsOf: url) {
			audioPlayer = player
			self.update = update
		} else {
			return nil
		}
		
		super.init()
		
		audioPlayer.delegate = self

		if let i = initialProgress {
			setProgress(i)
		}
		update(playState)
	}
	
	var playState: PlayState {
		return PlayState(isPlaying: audioPlayer.isPlaying, progress: audioPlayer.currentTime, duration: audioPlayer.duration)
	}
	
	func togglePlay() {
		if audioPlayer.isPlaying {
			audioPlayer.pause()
			timer?.invalidate()
			timer = nil
			update(playState)
		} else {
			audioPlayer.play()
			if let t = timer {
				t.invalidate()
			}
			timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
				guard let s = self else { return }
				s.update(s.playState)
			}
		}
	}
	
	func setProgress(_ time: TimeInterval) {
		audioPlayer.currentTime = time
	}

	func audioPlayerDidFinishPlaying(_ pl: AVAudioPlayer, successfully flag: Bool) {
		timer?.invalidate()
		timer = nil
		update(playState)
	}
	
	var duration: TimeInterval {
		return audioPlayer.duration
	}
	
	var isPlaying: Bool {
		return audioPlayer.isPlaying
	}
	
	var isPaused: Bool {
		return !audioPlayer.isPlaying && audioPlayer.currentTime > 0
	}
	
	deinit {
		timer?.invalidate()
	}
}
