import UIKit

struct FolderState: StateContainer {
	let uuid: UUID
	let isEditing: ToggleAdapter
	let selection = TempVar<TableRow<Item>>()
	
	init(folderUuid uuid: UUID) {
		self.uuid = uuid
		isEditing = ToggleAdapter(false)
	}
	var childValues: [StateContainer] { return [isEditing, selection] }
}

func folderView(_ folder: FolderState, _ split: SplitState, _ store: StoreAdapter) -> ViewControllerConvertible {
	return ViewController(
		.navigationItem -- navItemStyles(folder, split, store),
		.title <-- store.folderSignal(folder.uuid).map { folder in folder.name },
		.view -- TableView<Item>(
			.cellIdentifier -- { row in "FolderRow" },
			.cellConstructor -- { identifier, rowSignal in
				TableViewCell(
					.textLabel -- Label(
						.text <-- rowSignal
							.map { item in "\(item.isFolder ? "📁" : "🔊")  \(item.name)" }
					)
				)
			},
			.tableData <-- store.folderContentsSignal(folder.uuid).tableData(),
			.isEditing <-- folder.isEditing.animate(),
			.didSelectRow --> folder.selection,
			.deselectRow <-- folder.selection
				.delay(interval: .milliseconds(250))
				.map { .animate($0.indexPath) },
			.commit --> Input()
				.compactMap { styleAndRow in styleAndRow.row.data?.uuid }
				.map { uuid in .removeItem(uuid: uuid) }
				.bind(to: store),
			.cancelOnClose -- [
				folder.selection
					.compactMap { row in row.data?.folder }
					.map { folder in FolderState(folderUuid: folder.uuid) }
					.cancellableBind(to: split.navStack.pushInput),
				folder.selection
					.compactMap { row in row.data?.recording?.uuid }
					.cancellableBind(to: split.lastSelectedRecordingUuid)
			]
		)
	)
}

func navItemStyles(_ folder: FolderState, _ split: SplitState, _ store: StoreAdapter) -> NavigationItem {
	return NavigationItem(
		.leftBarButtonItems <-- folder.isEditing
			.map { isEditing in
				[BarButtonItem(
					.barButtonSystemItem -- isEditing ? .done : .edit,
					.action --> folder.isEditing.input
				)]
			}.animate(),
		.leftItemsSupplementBackButton -- true,
		.rightBarButtonItems -- .set([
			BarButtonItem(
				.barButtonSystemItem -- .add,
				.action --> Input().map { _ in .record(inParent: folder.uuid) }.bind(to: store)
			),
			BarButtonItem(
				.barButtonSystemItem -- .organize,
				.action --> Input()
					.map { _ in TextAlertState(parentUuid: folder.uuid) }
					.bind(to: split.textAlert)
			)
		])
	)
}

