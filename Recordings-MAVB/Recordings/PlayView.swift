import UIKit

struct PlayState: StateContainer {
	let uuid: UUID
	let url: URL
	let mediaState: Var<PlayerRecorderState>
	let mediaControl = TempVar<PlayerRecorderControl>()
	init(uuid: UUID, url: URL, restoreTime: TimeInterval? = nil) {
		self.uuid = uuid
		self.url = url
		self.mediaState = Var(PlayerRecorderState(progress: 0, duration: 0, active: false))
	}
	var childValues: [StateContainer] { return [mediaState] }
}

func playView(_ play: PlayState, _ split: SplitState, _ store: StoreAdapter) -> ViewControllerConvertible {
	return ViewController(
		.title <-- store.recordingSignal(play.uuid).map { recAndUrl in recAndUrl.rec.name },
		.view -- View(.backgroundColor -- UIColor.white),
		.navigationItem -- NavigationItem(
			.leftBarButtonItems <-- split.splitButton.optionalToArray().animate(.none)
		),
		.layout -- .vertical(
			.space(20),
			nameRow(play, store),
			.space(40),
			progressRow(play),
			.space(),
			.view(progressSlider(play)),
			.space(40),
			.view(playButton(play)),
			.space(.fillRemaining)
		),
		.cancelOnClose -- [
			AudioPlayer(
				url: play.url,
				input: play.mediaControl
					.mergeWith(AudioSession.shared.isActive.map { .audioSessionActive($0) })
					.startWith(PlayerRecorderControl.setProgress(play.mediaState.peek()?.progress ?? 0)),
				output: Input().multicast(
					Input()
						.ignoreElements()
						.catchError { _ in .just(nil) }
						.bind(to: split.playState),
					Input().bind(to: play.mediaState)
				)
			)
		]
	)
}

func playButton(_ play: PlayState) -> ButtonConvertible {
	return Button(recordingsAppButtonBindings:
		.title <-- play.mediaState.map { ps in
			.normal(ps.active ? .pauseLabel : .playLabel)
		},
		.action(.primaryActionTriggered) --> Input()
			.map { _ in .togglePlay }
			.bind(to: play.mediaControl)
	)

}

func nameRow(_ play: PlayState, _ store: StoreAdapter) -> Layout.Entity {
	return .horizontal(
		.view(Label(.text -- .nameLabel, .textAlignment -- .right)),
		.space(),
		.view(length: .fillRemaining,
			TextField(
				.text <-- store.recordingSignal(play.uuid).map { recAndUrl in recAndUrl.rec.name },
				.borderStyle -- .roundedRect,
				.shouldReturn -- textFieldResignOnReturn(),
				.didChange --> Input()
					.map { contents in .renameItem(uuid: play.uuid, newName: contents.text) }
					.bind(to: store)
			)
		)
	)
}

func progressRow(_ playState: PlayState) -> Layout.Entity {
	return .horizontal(
		.matchedPair(
			.view(
				Label(.text <-- playState.mediaState.map { timeString($0.progress) } )
			),
			.view(Label(
				.text <-- playState.mediaState.map { timeString($0.duration) },
				.textAlignment -- .right
			))
		)
	)
}


func progressSlider(_ play: PlayState) -> SliderConvertible {
	return Slider(
		.maximumValue <-- play.mediaState
			.map { chg in Float(chg.duration > 0 ? chg.duration : 1) },
		.value <-- play.mediaState
			.map { chg in .set(Float(chg.duration > 0 ? chg.progress : 0)) },
		.minimumTrackTintColor -- .black,
		.thumbTintColor -- .orangeTint,
		.action(.valueChanged) --> Input()
			.map { .setProgress(TimeInterval(($0.control as? UISlider)?.value ?? 0)) }
			.bind(to: play.mediaControl)
	)
}

fileprivate extension String {
	static let playLabel = NSLocalizedString("Play", comment: "")
	static let pauseLabel = NSLocalizedString("Pause", comment: "")
	static let nameLabel = NSLocalizedString("Name", comment: "")
}
