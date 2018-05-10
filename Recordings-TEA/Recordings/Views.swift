import UIKit

extension AppState {
	var viewController: ViewController<Message> {
		let rootView = SplitViewController<Message>(
			left: { _ in self.master },
			right: self.detail,
			collapseSecondaryViewController: playState == nil,
			popDetail: .popDetail)
		return .splitViewController(rootView, modal: recordModal)
	}
	
	var master: NavigationController<Message> {
		let viewControllers: [NavigationItem<Message>] = folders.map { folder in
			let tv: TableView<Message> = folder.tableView(onSelect: Message.select, onDelete: Message.delete)
			return NavigationItem(title: folder.name,
				leftBarButtonItem: .editButtonItem,
				rightBarButtonItems: [.system(.add, action: .createNewRecording),
					.system(.organize, action: .showCreateFolderPrompt)],
				leftItemsSupplementsBackButton: true,
				viewController: .tableViewController(tv))
		}
		return NavigationController(viewControllers: viewControllers, back: .back, popDetail: .popDetail)
	}
	
	func detail(displayModeButton: UIBarButtonItem?) -> NavigationController<Message> {
		let playerVC: ViewController<Message>? = playState?.viewController.map { .player($0) }
		return NavigationController<Message>(viewControllers: [
			NavigationItem(title: playState?.recording.name ?? "", leftBarButtonItem: displayModeButton.map { .builtin($0) } ?? .none, viewController: playerVC ?? noRecordingSelected())
		])
	}
	
	var recordModal: Modal<Message>? {
		return recordState.map { rec in
			Modal(viewController:
				recordViewController(duration: rec.duration, onStop: .recording(.stop)),
				presentationStyle: .formSheet)
		}
	}
}

extension Folder {
	func tableView<Message>(onSelect: (Item) -> Message, onDelete: (Item) -> Message) -> TableView<Message> {
		return TableView(items: items.map { item in
			let text: String
			switch item {
			case let .folder(folder):
				text = "📁  \(folder.name)"
			case let .recording(recording):
				text = "🔊  \(recording.name)"
			}
			return TableViewCell(identity: AnyHashable(item.uuid), text: text, onSelect: onSelect(item), onDelete: onDelete(item))
		})
	}
}

func noRecordingSelected<A>() -> ViewController<A> {
	return .viewController(.stackView(views: [.label(text: "No recording selected", font: .preferredFont(forTextStyle: .body))]))
}

extension PlayerState {
	var view: View<Message> {
		let nameView: View<Message> = View<Message>.stackView(views: [
			.label(text: "Name", font: .preferredFont(forTextStyle: .body)),
			.space(width: 10),
			.textField(text: name, onChange: { .nameChanged($0) }, onEnd: { .saveName($0) })
		], axis: .horizontal, distribution: .fill)
		
		let progressLabels: View<Message> = .stackView(views: [
			.label(text: timeString(position), font: .preferredFont(forTextStyle: .body)),
			.label(text: timeString(duration), font: .preferredFont(forTextStyle: .body))
		], axis: .horizontal)
		return View<Message>.stackView(views: [
			.stackView(views: [
				.space(height: 20),
				nameView,
				.space(height: 10),
				progressLabels,
				.space(height: 10),
				.slider(progress: Float(position), max: Float(duration), onChange: { .seek($0) }),
				.space(height: 20),
				.button(text: playing ? .pause : .play, onTap: .togglePlay),
			]),
			.space(width: nil, height: nil)
		])
	}
	
	var viewController: ViewController<Message> {
		return .viewController(view)
	}
}

func recordViewController<Message>(duration: TimeInterval, onStop: Message) -> ViewController<Message> {
	let rootView: View<Message> = .stackView(views: [
		.space(),
		.stackView(views: [
			.label(text: "Recording", font: .preferredFont(forTextStyle: .body)),
			.space(height: 10),
			.label(text: timeString(duration), font: .preferredFont(forTextStyle: .title1)),
			.space(height: 10),
			.button(text: "Stop", onTap: onStop),
		], distribution: .equalCentering),
		.space(width: nil, height: nil)
	], distribution: .equalCentering)
	return .viewController(rootView)
}

fileprivate extension String {
	static let newRecording = NSLocalizedString("New Recording", comment: "Title for recording view controller")
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}

