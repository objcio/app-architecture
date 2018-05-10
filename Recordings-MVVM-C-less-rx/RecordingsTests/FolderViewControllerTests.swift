import XCTest
import RxSwift
import RxCocoa
import RxDataSources
@testable import Recordings

let uuid1 = UUID()
let uuid2 = UUID()
let uuid3 = UUID()
let uuid4 = UUID()
let uuid5 = UUID()

func constructTestingStore() -> (Store, Folder, Folder) {
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
	
	return (store, folder1, folder2)
}

class FolderViewControllerTests: XCTestCase, UINavigationControllerDelegate {
	
	var store: Store = Store(url: nil)
	var childFolder1: Folder = Folder(name: "", uuid: UUID())
	var childFolder2: Folder = Folder(name: "", uuid: UUID())
	var viewModel: FolderViewModel! = nil
	var contentsObserved = [[AnimatableSectionModel<Int, Item>]]()
	var titleObserved = [String]()
	var disposeBag = DisposeBag()
	
	override func setUp() {
		super.setUp()
		
		(store, childFolder1, childFolder2) = constructTestingStore()
		
		viewModel = FolderViewModel()
		viewModel.folder = childFolder1
		
		viewModel.folderContents.subscribe(onNext: { [weak self] in
			self?.contentsObserved.append($0)
		}).disposed(by: disposeBag)
		viewModel.navigationTitle.subscribe(onNext: { [weak self] in
			self?.titleObserved.append($0)
		}).disposed(by: disposeBag)
	}
	
	override func tearDown() {
		super.tearDown()
	}
	
	func testFolderContents() {
		XCTAssert(contentsObserved.count == 1)
		
		guard contentsObserved.count == 1 else { XCTFail(); return }
		let sections1 = contentsObserved[0]
		guard sections1.count == 1 else { XCTFail(); return }
		let rows1 = sections1[0].items
		guard rows1.count == 2 else { XCTFail(); return }
		
		XCTAssert(rows1[0] == childFolder2)
		XCTAssert(rows1[1].uuid == uuid4)
		
		viewModel.folder = store.rootFolder
		
		guard contentsObserved.count == 2 else { XCTFail(); return }
		let sections2 = contentsObserved[1]
		guard sections2.count == 1 else { XCTFail(); return }
		let rows2 = sections2[0].items
		guard rows2.count == 2 else { XCTFail(); return }
		
		XCTAssert(rows2[0] == childFolder1)
		XCTAssert(rows2[1].uuid == uuid3)
	}
	
	func testFolderReemitOnFolderChange() {
		XCTAssert(contentsObserved.count == 1)
		
		childFolder1.setName("Something else")
		
		guard contentsObserved.count == 2 else { XCTFail(); return }
		let sections = contentsObserved[1]
		guard sections.count == 1 else { XCTFail(); return }
		let rows = sections[0].items
		guard rows.count == 2 else { XCTFail(); return }
		
		XCTAssert(rows[0] == childFolder2)
		XCTAssert(rows[1].uuid == uuid4)
	}
	
	func testFolderReemitOnChildRename() {
		XCTAssert(contentsObserved.count == 1)
		
		childFolder2.setName("Another name")
		
		guard contentsObserved.count == 2 else { XCTFail(); return }
		let sections = contentsObserved[1]
		guard sections.count == 1 else { XCTFail(); return }
		let rows = sections[0].items
		guard rows.count == 2 else { XCTFail(); return }
		
		XCTAssert(rows[0] == childFolder2)
		XCTAssert(rows[1].uuid == uuid4)
	}
	
	func testFolderSetToEmptyOnDeleted() {
		XCTAssert(contentsObserved.count == 1)
		
		store.rootFolder.remove(childFolder1)
		
		// Removing `childFolder1` results in three changes: first one change for each of the two
		// children of `childFolder1`, and then one change for `childFolder1` itself.
		guard contentsObserved.count == 4 else { XCTFail(); return }
		let sections = contentsObserved[3]
		guard sections.count == 1 else { XCTFail(); return }
		let rows = sections[0].items
		
		XCTAssert(rows.count == 0)
	}
	
	func testFolderCreate() {
		XCTAssert(contentsObserved.count == 1)
		
		viewModel.create(folderNamed: "Child 3")
		
		guard contentsObserved.count == 2 else { XCTFail(); return }
		let sections = contentsObserved[1]
		guard sections.count == 1 else { XCTFail(); return }
		let rows = sections[0].items
		guard rows.count == 3 else { XCTFail(); return }
		
		XCTAssert(rows[0] == childFolder2)
		XCTAssert(rows[1].name == "Child 3")
		XCTAssert(rows[2].uuid == uuid4)
	}
	
	func testFolderDelete() {
		// Test initial conditions
		XCTAssert(contentsObserved.count == 1)
		
		// Perform an action
		viewModel.deleteItem(childFolder2)
		
		// Test subsequent conditions
		guard contentsObserved.count == 2 else { XCTFail(); return }
		let sections = contentsObserved[1]
		guard sections.count == 1 else { XCTFail(); return }
		let rows = sections[0].items
		guard rows.count == 1 else { XCTFail(); return }
		XCTAssert(rows[0].uuid == uuid4)
	}
	
	func testNavigationTitle() {
		// Test initial conditions
		guard titleObserved.count == 1 else { XCTFail(); return }
		XCTAssert(titleObserved[0] == "Child 1")
		
		// Perform an action
		childFolder1.setName("Another name")
		
		// Test subsequent conditions
		guard titleObserved.count == 2 else { XCTFail(); return }
		XCTAssert(titleObserved[1] == "Another name")
		
		viewModel.folder = store.rootFolder
		
		guard titleObserved.count == 3 else { XCTFail(); return }
		XCTAssert(titleObserved[2] == "Recordings")
	}
}
