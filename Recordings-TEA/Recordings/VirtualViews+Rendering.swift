import UIKit

struct StrongReferences {
	private var handlers: [Any] = []
	
	init() {}
	
	mutating func append(_ obj: Any) {
		handlers.append(obj)
	}
	
	mutating func append(contentsOf other: [Any]) {
		handlers.append(contentsOf: other)
	}
}

class TargetAction: NSObject { // todo: removeTarget?
	var handle: () -> ()
	init(_ handle: @escaping () -> ()) {
		self.handle = handle
	}
	@objc func performAction(sender: UIButton) {
		handle()
	}
}

final class NCDelegate: NSObject, UINavigationControllerDelegate {
	var back: (() -> ())
	var popDetail: (() -> ())
	init(back: @escaping () -> (), popDetail: @escaping () -> ()) {
		self.back = back
		self.popDetail = popDetail
	}
	
	func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		if operation == .pop {
			if (navigationController.splitViewController?.delegate as? SplitViewControllerDelegate)?.detailViewController === fromVC {
				popDetail()
			} else {
				back()
			}
		}
		return nil
	}
}

let reusableCellIdentifier = "Cell"
class TableViewBacking<A>: NSObject, UITableViewDataSource, UITableViewDelegate {
	var cells: [TableViewCell<A>]
	var callback: ((A) -> ())?
	init(cells: [TableViewCell<A>], callback: ((A) -> ())? = nil) {
		self.cells = cells
		self.callback = callback
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cells.count
	}
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.row >= cells.count {
			return UITableViewCell()
		}
		let cell = tableView.dequeueReusableCell(withIdentifier: reusableCellIdentifier, for: indexPath)
		let item = cells[indexPath.row]
		cell.textLabel?.text = item.text
		cell.accessoryType = item.accessory
		return cell
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete, let action = cells[indexPath.row].onDelete {
			callback?(action)
		}
	}
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let value = cells[indexPath.row].onSelect {
			callback?(value)
		}
	}
}


final class SplitViewControllerDelegate: NSObject, UISplitViewControllerDelegate {
	var collapseSecondaryViewController: Bool
	var detailViewController: UIViewController
	
	init(detailViewController: UIViewController, collapseSecondaryViewController: Bool) {
		self.detailViewController = detailViewController
		self.collapseSecondaryViewController = collapseSecondaryViewController
	}
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		if let vc = (detailViewController as? UINavigationController)?.topViewController {
			if vc.navigationItem.leftBarButtonItem === splitViewController.displayModeButtonItem {
				vc.navigationItem.leftBarButtonItem = nil
			}
		}
		return collapseSecondaryViewController
	}
	func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
		(detailViewController as? UINavigationController)?.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
		return detailViewController
	}
}

extension BarButtonItem {
	func render(_ callback: @escaping (Message) -> (), viewController: UIViewController, change: inout UIBarButtonItem?) -> [Any] {
		switch self {
		case .builtin(let button):
			if change != button { change = button }
			return []
		case let .custom(text: text, action: action):
			let target = TargetAction { callback(action) }
			change = UIBarButtonItem(title: text, style: .plain, target: target, action: #selector(TargetAction.performAction(sender:)))
			return [target]
		case let .system(item, action: action):
			let target = TargetAction { callback(action) }
			change = UIBarButtonItem(barButtonSystemItem: item, target: target, action: #selector(TargetAction.performAction(sender:)))
			return [target]
		case .editButtonItem:
			change = viewController.editButtonItem
			return []
		case .none:
			change = nil
			return []
		}
	}
}


struct Renderer<Message> {
	var strongReferences = StrongReferences()
	
	private let callback: (Message) -> ()
	private let container: UIViewController
	
	var addedChildViewControllers: [UIViewController] = []
	var removedChildViewControllers: [UIViewController] = []
	
	init(callback: @escaping (Message) -> (), container: UIViewController) {
		self.callback = callback
		self.container = container
	}
	
	private mutating func render(_ button: Button<Message>, into b: UIButton) {
		b.removeTarget(nil, action: nil, for: .touchUpInside)
		if let action = button.onTap {
			let cb = self.callback
			let target = TargetAction { cb(action) }
			strongReferences.append(target)
			b.addTarget(target, action: #selector(TargetAction.performAction(sender:)), for: .touchUpInside)
		}
		
		b.setTitle(button.text, for: .normal)
		b.backgroundColor = .orangeTint
		b.setTitleColor(.white, for: .normal)
		b.titleLabel?.font = .preferredFont(forTextStyle: .headline)
		b.layer.cornerRadius = 4
	}
	
	private func render(_ label: Label, into l: UILabel) {
		l.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
		l.text = label.text
		l.font = label.font
		l.textAlignment = .center
	}
	
	// this does *not* render the children
	private func render(_ stackView: StackView<Message>, into result: UIStackView) {
		result.distribution = stackView.distribution
		result.axis = stackView.axis
		result.backgroundColor = stackView.backgroundColor
	}
	
	private mutating func render(_ textField: TextField<Message>, into result: UITextField) {
		result.text = textField.text
		result.borderStyle = .roundedRect
		result.removeTarget(nil, action: nil, for: .editingChanged)
		result.removeTarget(nil, action: nil, for: .editingDidEnd)
		result.removeTarget(nil, action: nil, for: .editingDidEndOnExit)
		if let onChange = textField.onChange {
			let cb = self.callback
			let changeTarget = TargetAction { [unowned result] in cb(onChange(result.text)) }
			result.addTarget(changeTarget, action: #selector(TargetAction.performAction(sender:)), for: .editingChanged)
			strongReferences.append(changeTarget)
		}
		if let onEnd = textField.onEnd {
			let cb = self.callback
			let endTarget = TargetAction { [unowned result] in cb(onEnd(result.text)) }
			result.addTarget(endTarget, action: #selector(TargetAction.performAction(sender:)), for: .editingDidEnd)
			result.addTarget(endTarget, action: #selector(TargetAction.performAction(sender:)), for: .editingDidEndOnExit)
			strongReferences.append(endTarget)
		}
	}
	
	private mutating func render(_ slider: Slider<Message>, into result: UISlider) {
		result.minimumValue = 0
		result.maximumValue = slider.max
		result.value = slider.progress
		result.minimumTrackTintColor = .black
		result.thumbTintColor = .orangeTint
		result.removeTarget(nil, action: nil, for: .valueChanged)
		if let action = slider.onChange {
			let cb = self.callback
			let target = TargetAction { [unowned result] in
				cb(action(result.value))
			}
			result.addTarget(target, action: #selector(TargetAction.performAction(sender:)), for: .valueChanged)
			strongReferences.append(target)
		}
	}
	
	mutating func render(_ tableView: TableView<Message>, into result: UITableView) {
		if let backing = result.delegate as? TableViewBacking<Message> {
			strongReferences.append(backing)
			
			// Perform a single pass through old and new items looking for updates, insertions, deletions and removals.
			var insertedIndex = nil as Int?
			var removedIndex = nil as Int?
			var needReload = false
			var updates = [Int]()
			var oldIndex = 0
			var newIndex = 0
			while oldIndex < backing.cells.count && newIndex < tableView.items.count {
				if backing.cells[oldIndex].identity != tableView.items[newIndex].identity {
					// Look for single inserted/deleted items
					if removedIndex == nil, oldIndex != backing.cells.count - 1, tableView.items[newIndex].identity == backing.cells[oldIndex + 1].identity {
						removedIndex = oldIndex
						oldIndex += 1
					} else if insertedIndex == nil, newIndex != tableView.items.count - 1, backing.cells[oldIndex].identity == tableView.items[newIndex + 1].identity {
						insertedIndex = newIndex
						newIndex += 1
					} else {
						// If more than one consecutive row fails to match, fallback to full reload
						needReload = true
						break
					}
				} else if backing.cells[oldIndex] != tableView.items[newIndex] {
					// If the rows are unequal, perform an update
					updates.append(newIndex)
				}
				oldIndex += 1
				newIndex += 1
			}
			
			if needReload == false {
				// Handle changes involving the last item
				if insertedIndex == nil, newIndex == tableView.items.count - 1 {
					insertedIndex = newIndex
				} else if removedIndex == nil, oldIndex == backing.cells.count - 1 {
					removedIndex = oldIndex
				} else if oldIndex != backing.cells.count && newIndex != tableView.items.count {
					needReload = true
				}
				
				// Double check we have a move, not an unrelated insert and delete
				if let ii = insertedIndex, let ri = removedIndex, backing.cells[ri].identity != tableView.items[ii].identity {
					needReload = true
				}
				
				// Nothing changed, don't tell the table view
				if needReload == false, insertedIndex == nil, removedIndex == nil, updates.isEmpty {
					backing.cells = tableView.items
					return
				}
			}
			
			// Set the changed data
			backing.cells = tableView.items
			
			// Don't animate if we need to reload
			if needReload {
				insertedIndex = nil
				removedIndex = nil
			}
			
			// Animated moves, insertions and deletions
			switch (insertedIndex, removedIndex) {
			case (.some(let ii), .some(let ri)):
				result.moveRow(at: IndexPath(row: ri, section: 0), to: IndexPath(row: ii, section: 0))
				updates.append(ii)
			case (.some(let ii), .none):
				result.insertRows(at: [IndexPath(row: ii, section: 0)], with: .automatic)
			case (.none, .some(let ri)):
				result.deleteRows(at: [IndexPath(row: ri, section: 0)], with: .automatic)
			default: result.reloadData()
			}
			
			// Reload unmoved but changed rows (updates for moved rows must be performed after the move or the animation won't work).
			if !needReload && !updates.isEmpty {
				result.reloadRows(at: updates.map { IndexPath(row: $0, section: 0) }, with: .automatic)
			}
		} else {
			let backing = TableViewBacking(cells: tableView.items, callback: self.callback)
			result.register(UITableViewCell.self, forCellReuseIdentifier: reusableCellIdentifier) // todo: don't register if we've already registered.
			result.delegate = backing
			result.dataSource = backing
			strongReferences.append(backing)
		}
	}
	
	func childViewController(for existing: UIView) -> UIViewController? {
		guard let i = container.childViewControllers.index(where: { $0.view == existing }) else { return nil }
		return container.childViewControllers[i]
	}
	
	mutating func render(view: View<Message>) -> UIView {
		switch view {
		case let ._label(label):
			let l = UILabel()
			render(label, into: l)
			return l
		case let ._stackView(stackView):
			let views = stackView.views.map { render(view: $0) }
			let result = UIStackView(arrangedSubviews: views)
			render(stackView, into: result)
			return result
		case let ._button(button):
			let b = UIButton()
			render(button, into: b)
			return b
		case let ._textField(textField):
			let result = UITextField()
			render(textField, into: result)
			return result
		case let ._imageView(imageView):
			return UIImageView(image: imageView.image)
		case let ._slider(slider):
			let result = UISlider()
			render(slider, into: result)
			return result
		case let ._tableView(tableView):
			let result = UITableView(frame: .zero, style: .plain)
			render(tableView, into: result)
			return result
		case let ._space(space):
			let v = UIView()
			v.translatesAutoresizingMaskIntoConstraints = false
			if let w = space.width {
				let c = v.widthAnchor.constraint(equalToConstant: w)
				c.priority = UILayoutPriority.defaultHigh
				c.isActive = true
			}
			if let h = space.height {
				let c = v.heightAnchor.constraint(equalToConstant: h)
				c.priority = UILayoutPriority.defaultHigh
				c.isActive = true
			}
			return v
		case let ._activityIndicator(indicator):
			let result = UIActivityIndicatorView(activityIndicatorStyle: indicator.style)
			result.startAnimating()
			return result
		case ._childViewController(let vc):
			var result = UIViewController()
			strongReferences.append(vc.render(callback: callback, change: &result))
			container.addChildViewController(result)
			addedChildViewControllers.append(result)
			return result.view
		case ._customLayout(let views):
			let container = UIView()
			container.translatesAutoresizingMaskIntoConstraints = false
			for (v,c) in views {
				let sub = render(view: v)
				container.addSubview(sub)
				sub.translatesAutoresizingMaskIntoConstraints = false
				container.addConstraints(c.map { $0(sub, container) })
			}
			return container
		}
	}
	
	mutating func removeChildViewController(for view: UIView) {
		guard let i = container.childViewControllers.index(where: { $0.view == view }) else { return }
		
		let child = container.childViewControllers[i]
		child.willMove(toParentViewController: nil)
		removedChildViewControllers.append(child)
	}
	
	mutating func update(view: View<Message>, into existing: UIView) -> UIView {
		switch view {
		case let ._label(label):
			guard let l = existing as? UILabel else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			render(label, into: l)
			return l
		case let ._stackView(stackView):
			guard let result = existing as? UIStackView, result.arrangedSubviews.count == stackView.views.count else {
				// todo: if the real view count is greater than the virtual view count, we can just remove the final views
				removeChildViewController(for: existing)
				return render(view: view)
			}
			for (index, existingSubview) in result.arrangedSubviews.enumerated() {
				let sub = stackView.views[index]
				let new = update(view: sub, into: existingSubview)
				if new !== existingSubview {
					result.removeArrangedSubview(existingSubview)
					existingSubview.removeFromSuperview()
					result.insertArrangedSubview(new, at: Int(index))
				}
			}
			render(stackView, into: result)
			return result
		case let ._button(button):
			guard let b = existing as? UIButton else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			render(button, into: b)
			return b
		case let ._activityIndicator(indicator):
			guard let a = existing as? UIActivityIndicatorView else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			a.activityIndicatorViewStyle = indicator.style
			return a
		case let ._textField(textField):
			guard let result = existing as? UITextField else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			render(textField, into: result)
			return result
		case let ._slider(slider):
			guard let result = existing as? UISlider else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			render(slider, into: result)
			return result
		case let ._imageView(imageView):
			guard let result = existing as? UIImageView else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			result.image = imageView.image
			return result
		case let ._tableView(tableView):
			guard let result = existing as? UITableView else {
				removeChildViewController(for: existing)
				return render(view: view)
			}
			render(tableView, into: result)
			return result
		case ._childViewController(let vc):
			guard let existingVC = childViewController(for: existing) else {
				removeChildViewController(for: existing) // unnecessary, but more symmetrical with the other cases
				return render(view: view)
			}
			var resultVC = existingVC
			strongReferences.append(vc.render(callback: callback, change: &resultVC))
			if resultVC != existingVC {
				existingVC.willMove(toParentViewController: nil)
				removedChildViewControllers.append(existingVC)
				container.addChildViewController(resultVC)
				addedChildViewControllers.append(resultVC)
			}
			return resultVC.view
		case ._space:
			removeChildViewController(for: existing)
			return render(view: view)
		case ._customLayout(let views):
			guard type(of: existing) == UIView.self else {
				removeChildViewController(for: existing)
				return render(view: view)
			}

			existing.translatesAutoresizingMaskIntoConstraints = false

			let subviewDifference = existing.subviews.count - views.count
			if subviewDifference < 0 {
				// add subviews
				for _ in 0..<(-subviewDifference) {
					let newView = UIView()
					newView.translatesAutoresizingMaskIntoConstraints = false
					existing.addSubview(newView)
				}
			} else if subviewDifference > 0 {
				// remove subviews
				for i in existing.subviews.count-subviewDifference..<existing.subviews.count {
					removeChildViewController(for: existing.subviews[i])
					existing.subviews[i].removeFromSuperview()
				}
			}
			assert(existing.subviews.count == views.count)

			for (i,v) in existing.subviews.enumerated() {
				let newChild = views[i]
				let newView = update(view: newChild.0, into: v)
				if newView != v {
					removeChildViewController(for: v)
					v.removeFromSuperview()
					newView.translatesAutoresizingMaskIntoConstraints = false
					existing.insertSubview(newView, at: i)
				}
				// delete all constraints, re-add them (todo could be optimized)
				let existingConstraints = existing.constraints.filter({ ($0.firstItem as? UIView) == existing.subviews[i] })
				existing.removeConstraints(existingConstraints)
				let newConstraints = newChild.1.map { $0(newView, existing) }
				existing.addConstraints(newConstraints)
			}
			return existing
		}
	}
}

extension Array {
	mutating func remove(where cond: (Element) -> Bool) {
		for i in indices.reversed() {
			if cond(self[i]) {
				self.remove(at: i)
			}
		}
	}
}

extension SplitViewController {
	static func styledNavigationController() -> UINavigationController {
		let n = UINavigationController()
		n.navigationBar.barTintColor = .blueTint
		n.navigationBar.tintColor = .orangeTint
		n.navigationBar.titleTextAttributes = [NSAttributedStringKey(rawValue: NSAttributedStringKey.foregroundColor.rawValue): UIColor.white]
		return n
	}
	
	func render(callback: @escaping (Message) -> (), viewController vc: UISplitViewController) -> StrongReferences {
		let delegate: SplitViewControllerDelegate
		if let svcd = vc.delegate as? SplitViewControllerDelegate {
			delegate = svcd
		} else {
			delegate = SplitViewControllerDelegate(detailViewController: SplitViewController.styledNavigationController(), collapseSecondaryViewController: collapseSecondaryViewController)
			vc.delegate = delegate
		}
		
		if vc.viewControllers == [] {
			vc.viewControllers = [SplitViewController.styledNavigationController(), delegate.detailViewController]
		}
		
		let nc = vc.viewControllers[0] as! UINavigationController
		var strongReferences: StrongReferences
		
		strongReferences = left(vc.displayModeButtonItem).render(callback: callback, viewController: nc)
		let detail: ViewController<Message> = .navigationController(right(vc.viewControllers.count == 1 ? nil : vc.displayModeButtonItem))
		strongReferences.append(detail.render(callback: callback, change: &delegate.detailViewController))
		
		if delegate.collapseSecondaryViewController, !collapseSecondaryViewController {
			vc.showDetailViewController(delegate.detailViewController, sender: nil)
		}
		delegate.collapseSecondaryViewController = collapseSecondaryViewController
		
		vc.preferredDisplayMode = .allVisible
		strongReferences.append(delegate)
		return strongReferences
		
	}
}

protocol Anchors {
	var bottomAnchor: NSLayoutYAxisAnchor { get }
	var topAnchor: NSLayoutYAxisAnchor { get }
	var leadingAnchor: NSLayoutXAxisAnchor { get }
	var trailingAnchor: NSLayoutXAxisAnchor { get }
}

extension UIView: Anchors { }
extension UILayoutGuide: Anchors { }

extension ViewController {
	func render(callback: @escaping (Message) -> (), change: inout UIViewController) -> StrongReferences {
		switch self {
		case let .navigationController(newNC):
			var n: UINavigationController! = change as? UINavigationController
			if n == nil {
				n = UINavigationController()
				change = n
			}
			return newNC.render(callback: callback, viewController: n)
		case let .tableViewController(view):
			var t: UITableViewController! = change as? UITableViewController
			if t == nil {
				t = UITableViewController()
				change = t
			}
			var r = Renderer(callback: callback, container: change)
			r.render(view, into: t.tableView)
			return r.strongReferences
		case let ._viewController(view, useLayoutGuide):
			if type(of: change) != UIViewController.self {
				change = UIViewController()
			}
			
			var r = Renderer(callback: callback, container: change)
			change.view.backgroundColor = .white
			let newView = r.update(view: view, into: change.view.subviews.first ?? UIView())
		
			if change.view.subviews.count == 0 || newView !== change.view.subviews[0] {
				if change.view.subviews.count != 0 {
					change.view.subviews[0].removeFromSuperview()
				}
				change.view.addSubview(newView)
				newView.translatesAutoresizingMaskIntoConstraints = false
				
				let verticalAnchors: Anchors
				let horizontalAnchors: Anchors = useLayoutGuide ? change.view.layoutMarginsGuide : change.view
				
				if useLayoutGuide {
					if #available(iOS 11.0, *) {
						verticalAnchors = change.view.safeAreaLayoutGuide
					} else {
						verticalAnchors = change.view.layoutMarginsGuide
					}
				} else {
					verticalAnchors = change.view
				}
				
				change.view.addConstraints([
					newView.topAnchor.constraint(equalTo: verticalAnchors.topAnchor),
					newView.bottomAnchor.constraint(equalTo: verticalAnchors.bottomAnchor),
					newView.leadingAnchor.constraint(equalTo: horizontalAnchors.leadingAnchor),
					newView.trailingAnchor.constraint(equalTo: horizontalAnchors.trailingAnchor)
				])
			}
			for removed in r.removedChildViewControllers {
				removed.removeFromParentViewController()
			}
			for added in r.addedChildViewControllers {
				added.didMove(toParentViewController: change)
			}
			return r.strongReferences
		case .splitViewController(let newSVC, let modal):
			var s: UISplitViewController! = change as? UISplitViewController
			if s == nil {
				s = UISplitViewController()
				change = s
			}
			var strongReferences = newSVC.render(callback: callback, viewController: s)
			if let modal = modal {
				if var v = s.presentedViewController {
					strongReferences.append(modal.viewController.render(callback: callback, change: &v))
					assert(v == s.presentedViewController)
				} else {
					var vc = UIViewController()
					strongReferences.append(modal.viewController.render(callback: callback, change: &vc))
					vc.modalPresentationStyle = modal.presentationStyle
					s.present(vc, animated: true, completion: nil)
				}
			} else {
				if let vc = s.presentedViewController, !(vc is UIAlertController) {
					vc.dismiss(animated: true, completion: nil)
				}
			}
			return strongReferences
		}
	}
}



extension NavigationItem {
	func render(callback: @escaping (Message) -> (), viewController: inout UIViewController) -> StrongReferences {
		var strongReferences = self.viewController.render(callback: callback, change: &viewController)
		let ni = viewController.navigationItem
		strongReferences.append(leftBarButtonItem?.render(callback, viewController: viewController, change: &ni.leftBarButtonItem) ?? [])
		ni.leftItemsSupplementBackButton = leftItemsSupplementsBackButton
		ni.title = title
		var rightBarButtonItems: [UIBarButtonItem] = []
		for button in self.rightBarButtonItems {
			var result: UIBarButtonItem? = nil
			strongReferences.append(contentsOf: button.render(callback, viewController: viewController, change: &result))
			if let r = result {
				rightBarButtonItems.append(r)
			}
		}
		ni.setRightBarButtonItems(rightBarButtonItems, animated: false)
		return strongReferences
	}
}

extension NavigationController {
	func render(callback: @escaping (Message) -> (), viewController nc: UINavigationController) -> StrongReferences {
		var strongReferences = StrongReferences()
		if let back = back, let popDetail = popDetail {
			let delegate = NCDelegate(back: { callback(back) }, popDetail: { callback(popDetail) })
			nc.delegate = delegate
			strongReferences.append(delegate)
		}
		
		let diffN = viewControllers.count - nc.viewControllers.count
		for (v, index) in zip(viewControllers, nc.viewControllers.indices) {
			strongReferences.append(v.render(callback: callback, viewController: &nc.viewControllers[index]))
		}
		
		if diffN > 0 {
			for v in viewControllers.last(diffN) {
				var vc = UIViewController()
				strongReferences.append(v.render(callback: callback, viewController: &vc))
				nc.pushViewController(vc, animated: true)
			}
		}
		return strongReferences
		
	}
}

extension Array {
	func last(_ n: Int) -> ArraySlice<Element> {
		return self[endIndex - n..<endIndex]
	}
}
