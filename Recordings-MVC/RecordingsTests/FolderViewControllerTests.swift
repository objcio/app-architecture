import XCTest
@testable import Recordings

let uuid1 = UUID()
let uuid2 = UUID()
let uuid3 = UUID()
let uuid4 = UUID()
let uuid5 = UUID()

func constructTestingStore() -> Store {
	let store = Store(url: nil)

	let folder1 = Folder(name: "Child 1", uuid: uuid1)
	let folder2 = Folder(name: "Child 2", uuid: uuid2)
	store.rootFolder.add(folder1)
	folder1.add(folder2)

	let recording1 = Recording(name: "Recording 1", uuid: uuid3)
	let recording2 = Recording(name: "Recording 2", uuid: uuid4)
	store.rootFolder.add(recording1)
	folder1.add(recording2)

	store.placeholder = Bundle(for: FolderViewControllerTests.self).url(forResource: "empty", withExtension: "m4a")!
	
	return store
}

func constructTestingViews(store: Store, navDelegate: UINavigationControllerDelegate) -> (UIStoryboard, AppDelegate, UISplitViewController, UINavigationController, FolderViewController) {
	let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)

	let navigationController = storyboard.instantiateViewController(withIdentifier: "navController") as! UINavigationController
	navigationController.delegate = navDelegate
	
	let rootFolderViewController = navigationController.viewControllers.first as! FolderViewController
	rootFolderViewController.folder = store.rootFolder
	rootFolderViewController.loadViewIfNeeded()

	let playViewController = storyboard.instantiateViewController(withIdentifier: "playerController")
	let detailNavigationController = UINavigationController(rootViewController: playViewController)
	let splitViewController = UISplitViewController(nibName: nil, bundle: nil)
	splitViewController.preferredDisplayMode = .allVisible
	splitViewController.viewControllers = [navigationController, detailNavigationController]
	
	let appDelegate = AppDelegate()
	splitViewController.delegate = appDelegate
	
	let window = UIWindow()
	window.rootViewController = splitViewController
	appDelegate.window = window
	
	window.makeKeyAndVisible()
	return (storyboard, appDelegate, splitViewController, navigationController, rootFolderViewController)
}

class FolderViewControllerTests: XCTestCase, UINavigationControllerDelegate {

	var store: Store! = nil
	var storyboard: UIStoryboard! = nil
	var appDelegate: AppDelegate! = nil
	var splitViewController: UISplitViewController! = nil
	var navigationController: UINavigationController! = nil
	var rootFolderViewController: FolderViewController! = nil
	var ex: XCTestExpectation? = nil
	
	override func setUp() {
		super.setUp()

		store = constructTestingStore()
		
		let tuple = constructTestingViews(store: store, navDelegate: self)
		storyboard = tuple.0
		appDelegate = tuple.1
		splitViewController = tuple.2
		navigationController = tuple.3
		rootFolderViewController = tuple.4
	}
	
	override func tearDown() {
		store = nil
		super.tearDown()
	}
	
	func testRootFolderStartupConfiguration() {
		let viewControllers = navigationController.viewControllers
		XCTAssert(viewControllers.first as? FolderViewController == rootFolderViewController)
		
		let navigationItemTitle = rootFolderViewController.navigationItem.title
		XCTAssert(navigationItemTitle == "Recordings")
		
		let delegate = rootFolderViewController.tableView.delegate as? FolderViewController
		XCTAssert(delegate == rootFolderViewController)
		
		let dataSource = rootFolderViewController.tableView.dataSource as? FolderViewController
		XCTAssert(dataSource == rootFolderViewController)
		
		let navigationItemLeftButtonTitle = rootFolderViewController.navigationItem.leftBarButtonItem?.title
		XCTAssert(navigationItemLeftButtonTitle == "Edit")
		
		let navigationItemRightButtons = rootFolderViewController.navigationItem.rightBarButtonItems
		XCTAssert(navigationItemRightButtons?.first?.target === rootFolderViewController)
		XCTAssert(navigationItemRightButtons?.first?.action == #selector(FolderViewController.createNewRecording(_:)))
		XCTAssert(navigationItemRightButtons?.last?.target === rootFolderViewController)
		XCTAssert(navigationItemRightButtons?.last?.action == #selector(FolderViewController.createNewFolder(_:)))
	}
		
	func testRootTableViewLayout() {
		let sectionsCount = rootFolderViewController.numberOfSections(in: rootFolderViewController.tableView)
		XCTAssert(sectionsCount == 1)
		
		let sectionZeroRowCount = rootFolderViewController.tableView(rootFolderViewController.tableView, numberOfRowsInSection: 0)
		XCTAssert(sectionZeroRowCount == 2)
		
		let firstCell = rootFolderViewController.tableView(rootFolderViewController.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
		XCTAssert(firstCell.textLabel!.text == "📁  Child 1")
		
		let secondCell = rootFolderViewController.tableView(rootFolderViewController.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
		XCTAssert(secondCell.textLabel!.text == "🔊  Recording 1")
	}
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		ex?.fulfill()
		ex = nil
	}
	
	func testSelectedFolder() {
		ex = expectation(description: "Wait for segue")
		rootFolderViewController.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
		rootFolderViewController.performSegue(withIdentifier: "showFolder", sender: nil)
		waitForExpectations(timeout: 5.0)
		XCTAssertEqual(navigationController.viewControllers.count, 2)
		XCTAssertEqual((navigationController.viewControllers.last as? FolderViewController)?.folder.uuid, uuid1)
	}
	
	func testSelectedRecording() {
		// Select the row (so `prepare(for:sender:)` can read the selection
		rootFolderViewController.tableView.selectRow(at: IndexPath(row: 1, section: 0), animated: false, scrollPosition: .none)

		// Handle collapsed or uncollapsed split view controller
		if self.splitViewController.viewControllers.count == 1 {
			ex = expectation(description: "Wait for segue")

			// Trigger the transition
			rootFolderViewController.performSegue(withIdentifier: "showPlayer", sender: nil)

			// Wait for the navigation controller to push the collapsed detail view
			waitForExpectations(timeout: 5.0)
			// Traverse to the `PlayViewController`
			let collapsedNC = navigationController.viewControllers.last as? UINavigationController
			let playVC = collapsedNC?.viewControllers.last as? PlayViewController

			// Test the result
			XCTAssertEqual(playVC?.recording?.uuid, uuid3)
		} else {
			rootFolderViewController.performSegue(withIdentifier: "showPlayer", sender: nil)
			let playVC = (self.splitViewController.viewControllers.last as? UINavigationController)?.topViewController as? PlayViewController
			XCTAssertEqual(playVC?.recording?.uuid, uuid3)
		}
	}
	
	func testDeletedCurrentFolder() {
		let childViewController = storyboard.instantiateViewController(withIdentifier: "folderController") as! FolderViewController
		guard let folder = store.item(atUUIDPath: [store.rootFolder.uuid, uuid1]) as? Folder else {
			XCTFail()
			return
		}
		childViewController.folder = folder
		navigationController.pushViewController(childViewController, animated: false)
		XCTAssert(self.navigationController.viewControllers.count == 2)
		XCTAssert((self.navigationController.viewControllers.last as? FolderViewController)?.folder.uuid == uuid1)
		
		store.rootFolder.remove(folder)
		XCTAssert(self.navigationController.viewControllers.count == 1)
		XCTAssert((self.navigationController.viewControllers.last as? FolderViewController)?.folder.uuid == self.store.rootFolder.uuid)
	}
	
	func testChildFolderConfigurationAndLayout() {
		let childViewController = storyboard.instantiateViewController(withIdentifier: "folderController") as! FolderViewController
		guard let folder = store.item(atUUIDPath: [store.rootFolder.uuid, uuid1]) as? Folder else {
			XCTFail()
			return
		}
		childViewController.folder = folder

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
	
	func testCreateNewFolder() {
		rootFolderViewController.createNewFolder(nil)
		XCTAssert(rootFolderViewController.presentedViewController?.title == "Create Folder")
		rootFolderViewController.dismiss(animated: false, completion: nil)
	}
	
	func testCreateNewRecording() {
		rootFolderViewController.createNewRecording(nil)
		XCTAssert(rootFolderViewController.presentedViewController is RecordViewController)
		rootFolderViewController.dismiss(animated: false, completion: nil)
	}
	
	func testCommitEditing() {
		// Verify that the action we will invoke is connected
		let dataSource = rootFolderViewController.tableView.dataSource as? FolderViewController
		XCTAssertEqual(dataSource, rootFolderViewController)
		
		// Confirm item exists before
		XCTAssertNotNil(store.item(atUUIDPath: [store.rootFolder.uuid, uuid3]))

		// Perform the action
		rootFolderViewController.tableView(rootFolderViewController.tableView, commit: .delete, forRowAt: IndexPath(row: 1, section: 0))

		// Assert item is gone afterwards
		XCTAssertNil(store.item(atUUIDPath: [store.rootFolder.uuid, uuid3]))
	}

	func testChangeNotificationHandling() {
		let folder3 = Folder(name: "Child 3", uuid: UUID())
		store.rootFolder.add(folder3)
		
		let sectionZeroRowCount = self.rootFolderViewController.tableView(self.rootFolderViewController.tableView, numberOfRowsInSection: 0)
		XCTAssert(sectionZeroRowCount == 3)
		let secondCell = self.rootFolderViewController.tableView.cellForRow(at: IndexPath(row: 1, section: 0))
		XCTAssert(secondCell?.textLabel?.text == "📁  Child 3")
		
		folder3.setName("Something else")
		let secondCellAgain = self.rootFolderViewController.tableView.cellForRow(at: IndexPath(row: 2, section: 0))
		XCTAssert(secondCellAgain?.textLabel?.text == "📁  Something else")
		
		self.store.rootFolder.remove(folder3)
		let sectionZeroFinalRowCount = self.rootFolderViewController.tableView(self.rootFolderViewController.tableView, numberOfRowsInSection: 0)
		XCTAssert(sectionZeroFinalRowCount == 2)
		let recordingCell = self.rootFolderViewController.tableView.cellForRow(at: IndexPath(row: 1, section: 0))
		XCTAssert(recordingCell?.textLabel?.text == "🔊  Recording 1")
	}
}


