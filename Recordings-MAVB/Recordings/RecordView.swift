import UIKit

struct RecordState: StateContainer {
	let url: URL
	let mediaState = TempVar(PlayerRecorderState(progress: 0, duration: 0, active: false))
	let mediaControl = TempVar<PlayerRecorderControl>()
	
	init?(tempFile: Store.TempFile?) {
		guard let tf = tempFile, tf.isRecorded != true else { return nil }
		self.url = tf.url
	}
}

func recordView(_ record: RecordState, _ split: SplitState, _ store: StoreAdapter) -> ViewController {
	return ViewController(
		.modalPresentationStyle -- .formSheet,
		.view -- View(
			.layoutMargins -- UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20),
			.backgroundColor -- UIColor.white,
			.layout -- .horizontal(
				align: .center,
				marginEdges: .allLayout,
				.vertical(
					align: .center,
					.view(Label(.text -- .recordingLabel)),
					.view(Label(
						.text <-- record.mediaState.map { timeString($0.progress) },
						.font -- .preferredFont(forTextStyle: .title1)
					)),
					.view(breadth: .equalTo(ratio: 1),
						Button(recordingsAppButtonBindings:
							.title -- .normal(.stopTitle),
							.action(.primaryActionTriggered) --> Input().multicast(
								Input().map { _ in .stop }.bind(to: record.mediaControl),
								Input().map { _ in .recordingComplete }.bind(to: store)
							)
						)
					)
				)
			)
		),
		.cancelOnClose -- [
			AudioRecorder(
				url: record.url,
				input: record.mediaControl
					.mergeWith(AudioSession.shared.isActive.map { .audioSessionActive($0) }),
				output: record.mediaState.input
			)
		]
	)
}

fileprivate extension String {
	static let recordingLabel = NSLocalizedString("Recording", comment: "")
	static let stopTitle = NSLocalizedString("Stop", comment: "")
}
