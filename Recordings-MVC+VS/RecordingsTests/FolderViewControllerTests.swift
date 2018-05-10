import XCTest
@testable import Recordings

let uuid1 = UUID()
let uuid2 = UUID()
let uuid3 = UUID()
let uuid4 = UUID()
let uuid5 = UUID()

func constructTestingStore() -> DocumentStore {
	let root = DocumentStore.rootFolderUUID
	let content: [UUID: Item] = [
		root: .folder(Folder(name: "", uuid: root, parentUUID: nil, childUUIDs: [uuid1, uuid3])),
		uuid1: .folder(Folder(name: "Child 1", uuid: uuid1, parentUUID: root, childUUIDs: [uuid2, uuid4])),
		uuid3: .recording(Recording(name: "Recording 1", uuid: uuid3, parentUUID: root)),
		uuid2: .folder(Folder(name: "Child 2", uuid: uuid2, parentUUID: uuid1, childUUIDs: [])),
		uuid4: .recording(Recording(name: "Recording 2", uuid: uuid4, parentUUID: uuid1))
	]
	let store = DocumentStore(url: nil)
	store.loadWithoutNotifying(jsonData: try! JSONEncoder().encode(content))
	return store
}

class FolderViewControllerTests: XCTestCase, UINavigationControllerDelegate {

	var documentStore: DocumentStore! = nil
	var viewStateStore: ViewStateStore! = nil
	var splitViewController: SplitViewController! = nil
	var ex: XCTestExpectation? = nil
	
	override func setUp() {
		super.setUp()

		documentStore = constructTestingStore()
		viewStateStore = ViewStateStore()

		let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
		splitViewController = storyboard.instantiateInitialViewController() as! SplitViewController
		splitViewController.context = StoreContext(documentStore: documentStore, viewStateStore: viewStateStore)
		splitViewController.loadViewIfNeeded()
	}
	
	override func tearDown() {
		documentStore = nil
		viewStateStore = nil
		splitViewController = nil
		super.tearDown()
	}
	
	func testRootFolderStartupConfiguration() {
		guard let navController = splitViewController.viewControllers.first as? UINavigationController else { XCTFail(); return }
		guard let rootFolderViewController = navController.topViewController as? FolderViewController else { XCTFail(); return }

		let navigationItemTitle = rootFolderViewController.navigationItem.title
		XCTAssert(navigationItemTitle == "Recordings")

		let delegate = rootFolderViewController.tableView.delegate as? FolderViewController
		XCTAssert(delegate == rootFolderViewController)

		let dataSource = rootFolderViewController.tableView.dataSource as? FolderViewController
		XCTAssert(dataSource == rootFolderViewController)

		let navigationItemLeftButtonAction = rootFolderViewController.navigationItem.leftBarButtonItem?.action
		XCTAssert(navigationItemLeftButtonAction == #selector(FolderViewController.toggleEditing(_:)))

		let navigationItemRightButtons = rootFolderViewController.navigationItem.rightBarButtonItems
		XCTAssert(navigationItemRightButtons?.first?.target === rootFolderViewController)
		XCTAssert(navigationItemRightButtons?.first?.action == #selector(FolderViewController.createNewRecording(_:)))
		XCTAssert(navigationItemRightButtons?.last?.target === rootFolderViewController)
		XCTAssert(navigationItemRightButtons?.last?.action == #selector(FolderViewController.createNewFolder(_:)))
	}
	
	func testRootTableViewLayout() {
		guard let navController = splitViewController.viewControllers.first as? UINavigationController else { XCTFail(); return }
		guard let rootFolderViewController = navController.topViewController as? FolderViewController else { XCTFail(); return }

		let sectionsCount = rootFolderViewController.numberOfSections(in: rootFolderViewController.tableView)
		XCTAssertEqual(sectionsCount, 1)

		let sectionZeroRowCount = rootFolderViewController.tableView(rootFolderViewController.tableView, numberOfRowsInSection: 0)
		XCTAssertEqual(sectionZeroRowCount, 2)

		let firstCell = rootFolderViewController.tableView(rootFolderViewController.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
		XCTAssertEqual(firstCell.textLabel!.text, "📁  Child 1")

		let secondCell = rootFolderViewController.tableView(rootFolderViewController.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
		XCTAssertEqual(secondCell.textLabel!.text, "🔊  Recording 1")
	}
	
	func testSelectedFolder() throws {
		guard let navController = splitViewController.viewControllers.first as? UINavigationController else { XCTFail(); return }
		guard let rootFolderViewController = navController.topViewController as? FolderViewController else { XCTFail(); return }
		
		// Check initial conditions
		XCTAssertEqual(viewStateStore.content.folderViews.count, 1)

		// Perform change
		rootFolderViewController.tableView(rootFolderViewController.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
		
		// Check final state
		guard viewStateStore.content.folderViews.count == 2 else { XCTFail(); return }
		XCTAssertEqual(viewStateStore.content.folderViews[1].folderUUID, uuid1)
	}

	func testSelectedRecording() {
		guard let navController = splitViewController.viewControllers.first as? UINavigationController else { XCTFail(); return }
		guard let rootFolderViewController = navController.topViewController as? FolderViewController else { XCTFail(); return }

		XCTAssert(viewStateStore.playView.uuid == nil)
		rootFolderViewController.tableView(rootFolderViewController.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
		XCTAssert(viewStateStore.playView.uuid == uuid3)
	}
	
	func testChildFolderConfigurationAndLayout() {
		let content = SplitViewState(folderViews: [
			FolderViewState(uuid: DocumentStore.rootFolderUUID),
			FolderViewState(uuid: uuid1)
		])
		viewStateStore.reloadAndNotify(jsonData: try! JSONEncoder().encode(content))

		guard splitViewController.viewControllers.count == 2 else { XCTFail(); return }
		guard let navController = splitViewController.viewControllers.first as? UINavigationController else { XCTFail(); return }
		guard let childViewController = navController.topViewController as? FolderViewController else { XCTFail(); return }
		navController.viewControllers.last?.loadViewIfNeeded()

		let navigationItemTitle = childViewController.navigationItem.title
		XCTAssert(navigationItemTitle == "Child 1")

		let sectionsCount = childViewController.numberOfSections(in: childViewController.tableView)
		XCTAssert(sectionsCount == 1)

		let sectionZeroRowCount = childViewController.tableView(childViewController.tableView, numberOfRowsInSection: 0)
		XCTAssert(sectionZeroRowCount == 2)

		let firstCell = childViewController.tableView(childViewController.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
		XCTAssert(firstCell.textLabel!.text == "📁  Child 2")

		let secondCell = childViewController.tableView(childViewController.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
		XCTAssert(secondCell.textLabel!.text == "🔊  Recording 2")
	}
	
	func testSample() {
		let content = SplitViewState(
			folderViews: [
				FolderViewState(uuid: DocumentStore.rootFolderUUID),
				FolderViewState(uuid: uuid1)
			],
			playView: PlayViewState(uuid: uuid2, playState: PlayState(isPlaying: false, progress: 0, duration: 10)),
			textAlert: TextAlertState(text: "Text", parentUUID: uuid2, recordingUUID: nil)
		)
		viewStateStore.reloadAndNotify(jsonData: try! JSONEncoder().encode(content))
		
	}
}
