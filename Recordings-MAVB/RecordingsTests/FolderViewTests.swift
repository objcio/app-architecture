import XCTest
@testable import Recordings

let uuid1 = UUID()
let uuid2 = UUID()
let uuid3 = UUID()
let uuid4 = UUID()
let uuid5 = UUID()

func constructTestingStore() -> StoreAdapter {
	let store = Store(relativePath: "store.json", items: [
		Item(Folder(name: "Recordings", uuid: Store.rootFolderUuid, parentUuid: nil, childUuids: [uuid1, uuid3])),
		Item(Folder(name: "Child 1", uuid: uuid1, parentUuid: Store.rootFolderUuid, childUuids: [uuid2, uuid4])),
		Item(Folder(name: "Child 2", uuid: uuid2, parentUuid: uuid1, childUuids: [])),
		Item(Recording(name: "Recording 1", uuid: uuid3, parentUuid: Store.rootFolderUuid)),
		Item(Recording(name: "Recording 2", uuid: uuid4, parentUuid: uuid1)),
	])
	return StoreAdapter(store: store)
}

class FolderView: XCTestCase {
	var store: StoreAdapter = StoreAdapter(store: Store(relativePath: nil))
	var rootFolder: FolderState!
	var childFolder: FolderState!
	var split: SplitState!
	var rootViewController: ViewControllerConvertible!
	var childViewController: ViewControllerConvertible!
	
	override func setUp() {
		super.setUp()
		
		store = constructTestingStore()
		rootFolder = FolderState(folderUuid: Store.rootFolderUuid)
		childFolder = FolderState(folderUuid: uuid1)
		split = SplitState()
		rootViewController = folderView(rootFolder, split, store)
		childViewController = folderView(childFolder, split, store)
	}
	
	func testTableData() throws {
		let viewControllerBindings = try ViewController.consumeBindings(from: rootViewController)
		let tableView = try ViewController.Binding.value(for: .view, in: viewControllerBindings)
		let tableViewBindings = try TableView<Item>.consumeBindings(from: tableView)
		let tableStructure = try TableView.Binding.tableStructure(in: tableViewBindings)
		
		XCTAssertEqual(tableStructure.rows.count, 1)
		
		let rows = tableStructure.rows.at(0)?.rowState.rows
		XCTAssertEqual(rows?.map { $0.uuid }, [uuid1, uuid3])
	}

	func testTableCell() throws {
		let viewControllerBindings = try ViewController.consumeBindings(from: rootViewController)
		let tableView = try ViewController.Binding.value(for: .view, in: viewControllerBindings)
		let tableViewBindings = try TableView<Item>.consumeBindings(from: tableView)
		let cellConstructor = try TableView.Binding.argument(for: .cellConstructor, in: tableViewBindings)

		let testFolder = Item(Folder(name: "Abc", uuid: uuid5, parentUuid: nil, childUuids: []))
		let cell = cellConstructor("FolderRow", Signal<Item>.preclosed(testFolder))
		let cellBindings = try TableViewCell.consumeBindings(from: cell)
		let textLabel = try TableViewCell.Binding.value(for: .textLabel, in: cellBindings)
		let textLabelBindings = try Label.consumeBindings(from: textLabel)
		let text = try Label.Binding.value(for: .text, in: textLabelBindings)
		
		XCTAssertEqual(text, "📁  Abc")
	}

	func testCreateNewFolder() throws {
		// Consume from the view controller
		let vcBindings = try ViewController.consumeBindings(from: rootViewController)
		let item = try ViewController.Binding.value(for: .navigationItem, in: vcBindings)
		
		// Consume from the navigation item
		let itemBindings = try NavigationItem.consumeBindings(from: item)
		let rightItems = try NavigationItem.Binding.value(for: .rightBarButtonItems, in: itemBindings)
		guard let addItem = rightItems.value.at(1) else { XCTFail(); return }
		
		// Consume from the bar button item
		let addBindings = try BarButtonItem.consumeBindings(from: addItem)
		let targetAction = try BarButtonItem.Binding.argument(for: .action, in: addBindings)
		guard case .singleTarget(let actionInput) = targetAction else { XCTFail(); return }
		
		var values = [TextAlertState?]()
		split.textAlert.subscribeValuesUntilEnd { values.append($0) }

		XCTAssert(values.at(0)?.isNil == true)
		actionInput.send(value: ())
		XCTAssertEqual(values.at(1)??.parentUuid, Store.rootFolderUuid)
	}

	func testRootFolderNavigationTitle() throws {
		let viewControllerBindings = try ViewController.consumeBindings(from: rootViewController)
		let title = try ViewController.Binding.value(for: .title, in: viewControllerBindings)
		XCTAssertEqual(title, "Recordings")
	}

	func testChildFolderNavigationTitle() throws {
		let bindings = try ViewController.consumeBindings(from: childViewController)
		let childTitle = try ViewController.Binding.signal(for: .title, in: bindings)
		
		var values = [String]()
		childTitle.subscribeValuesUntilEnd { values.append($0) }
		
		XCTAssertEqual(values.at(0), "Child 1")
		store.input.send(value: .renameItem(uuid: uuid1, newName: "New name"))
		XCTAssertEqual(values.at(1), "New name")
	}
}
