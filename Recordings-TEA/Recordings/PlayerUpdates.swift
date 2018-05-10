import Foundation

extension PlayerState {
	enum Message: Equatable {
		case togglePlay
		case nameChanged(String?)
		case saveName(String?)
		case seek(Float)
		case playPositionChanged(TimeInterval?, isPlaying: Bool)
	}
	
	mutating func update(_ action: Message) -> [Command<AppState.Message>] {
		switch action {
		case let .nameChanged(name):
			self.name = name ?? ""
			return []
		case let .saveName(name):
			return [Command.changeName(of: recording, to: name ?? "")]
		case .togglePlay:
			playing = !playing
			return [Command.togglePlay(player)]
		case let .playPositionChanged(position, isPlaying):
			self.position = position ?? duration
			playing = isPlaying
		case let .seek(progress):
			return [Command.seek(player, to: TimeInterval(progress))]
		}
		return []
	}
}
