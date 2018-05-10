import Foundation
import AVFoundation

class Player: NSObject, AVAudioPlayerDelegate {
	private var audioPlayer: AVAudioPlayer
	private var timer: Timer?
	var update: ((TimeInterval?, _ isPlaying: Bool) -> ())?
	
	init?(url: URL, update: ((TimeInterval?, _ isPlaying: Bool) -> ())? = nil) {
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			return nil
		}
		
		do {
			let player = try AVAudioPlayer(contentsOf: url)
			audioPlayer = player
			self.update = update
		} catch {
			print(error)
			return nil
		}
		super.init()
		
		audioPlayer.delegate = self
	}
	
	func togglePlay() {
		if audioPlayer.isPlaying {
			audioPlayer.pause()
			timer?.invalidate()
			timer = nil
		} else {
			audioPlayer.play()
			if let t = timer {
				t.invalidate()
			}
			timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
				guard let s = self else { return }
				s.update?(s.audioPlayer.currentTime, true)
			}
		}
	}
	
	func setProgress(_ time: TimeInterval) {
		audioPlayer.currentTime = time
		update?(audioPlayer.currentTime, isPlaying)
	}
	
	func audioPlayerDidFinishPlaying(_ pl: AVAudioPlayer, successfully flag: Bool) {
		timer?.invalidate()
		timer = nil
		update?(flag ? audioPlayer.currentTime : nil, false)
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
