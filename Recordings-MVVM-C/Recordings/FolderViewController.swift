import UIKit
import RxSwift
import RxCocoa
import RxDataSources

protocol FolderViewControllerDelegate: class {
	func didSelect(_ item: Item)
	func createRecording(in folder: Folder)
}

class FolderViewController: UITableViewController {
	weak var delegate: FolderViewControllerDelegate? = nil
	
	let viewModel = FolderViewModel()
	let disposeBag = DisposeBag()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.navigationTitle.bind(to: rx.title).disposed(by: disposeBag)
		viewModel.folderContents.bind(to: tableView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
		tableView.rx.modelDeleted(Item.self)
			.subscribe(onNext: { [unowned self] in self.viewModel.deleteItem($0) }).disposed(by: disposeBag)
		tableView.rx.modelSelected(Item.self)
			.subscribe(onNext: { [unowned self] in self.delegate?.didSelect($0) }).disposed(by: disposeBag)
	}
	
	var dataSource: RxTableViewSectionedAnimatedDataSource<AnimatableSectionModel<Int, Item>> {
		return RxTableViewSectionedAnimatedDataSource<AnimatableSectionModel<Int, Item>>(
			configureCell: { (dataSource, table, idxPath, item) in
				let identifier = item is Recording ? "RecordingCell" : "FolderCell"
				let cell = table.dequeueReusableCell(withIdentifier: identifier, for: idxPath)
				cell.textLabel!.text = FolderViewModel.text(for: item)
				return cell
			},
			canEditRowAtIndexPath: { _, _ in
				return true
			}
		)
	}
	
	// MARK: Actions
	
	@IBAction func createNewFolder(_ sender: Any) {
		modalTextAlert(title: .createFolder, accept: .create, placeholder: .folderName) { string in
			self.viewModel.create(folderNamed: string)
			self.dismiss(animated: true)
		}
	}
	
	@IBAction func createNewRecording(_ sender: Any) {
		delegate?.createRecording(in: viewModel.folder.value)
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(viewModel.folder.value.uuidPath, forKey: .uuidPathKey)
	}

	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let folder = Store.shared.item(atUUIDPath: uuidPath) as? Folder {
			self.viewModel.folder.value = folder
		} else {
			if var controllers = navigationController?.viewControllers, let index = controllers.index(where: { $0 === self }) {
				controllers.remove(at: index)
				navigationController?.viewControllers = controllers
			}
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
}

