import UIKit

class ServerViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {
	let browser = NetServiceBrowser()
	var operations = [ServerOperation]()
	var resolving = [NetService]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		browser.delegate = self
		browser.searchForServices(ofType: "_recordings._tcp.", inDomain: "local")
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return operations.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let operation = operations[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: operation.uuid != nil ? "Resolved" : "Unresolved", for: indexPath)
		if operation.uuid != nil {
			// Successfully connected
			cell.textLabel!.text = "🖥  \(operation.name)"
		} else if operation.task != nil {
			// Resolve or UUID fetch is still running
			cell.textLabel!.text = "❓  \(operation.name)"
		} else {
			// UUID fetch failed (firewall or other problem)
			cell.textLabel!.text = "❌  \(operation.name)"
		}
		return cell
	}
	
	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		if service.hostName != nil {
			self.netServiceDidResolveAddress(service)
		} else {
			resolving.append(service)
			service.delegate = self
			service.resolve(withTimeout: 60)
		}
	}
	
	func netServiceDidResolveAddress(_ service: NetService) {
		guard let hostName = service.hostName else { return }
		
		let operation: ServerOperation
		let insert: Bool
		let index: Int
		// The combination of type, domain and name should be unique but since we're searching for 1 type in the local domain, just `name` should be enough for identity.
		if let i = operations.index(where: { $0.name == service.name }) {
			operation = operations[i]
			operation.name = service.name
			operation.port = service.port
			insert = false
			index = i
		} else {
			operation = ServerOperation(name: service.name, hostName: hostName, port: service.port)
			operations.append(operation)
			operations.sort { (a, b) in a.name < b.name }
			index = operations.index { $0 === operation }!
			insert = true
		}
		operation.start { [weak self] o in
			if let index = self?.operations.index(where: { $0 === operation }) {
				self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
			}
		}
		if insert {
			self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
		} else {
			self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
		}
		service.stop()
	}

	func netServiceDidStop(_ service: NetService, didNotResolve errorDict: [String : NSNumber]) {
		service.stop()
	}

	func netServiceDidStop(_ service: NetService) {
		// The combination of type, domain and name should be unique but since we're searching for 1 type in the local domain, just `name` should be enough for identity.
		if let index = resolving.index(where: { $0.name == service.name }) {
			resolving.remove(at: index)
		}
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
		// The combination of type, domain and name should be unique but since we're searching for 1 type in the local domain, just `name` should be enough for identity.
		if let index = operations.index(where: { $0.name == service.name }) {
			operations.remove(at: index)
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let folderViewController = segue.destination as? FolderViewController, let indexPath = tableView.indexPathForSelectedRow, indexPath.row < operations.count, let uuid = operations[indexPath.row].uuid {
			let operation = operations[indexPath.row]
			folderViewController.store = Server(hostName: operation.hostName, port: operation.port, uuid: uuid)
			folderViewController.folder = folderViewController.store.rootFolder
		}
	}
}
