import UIKit

final class Driver<Model, Message> where Model: Codable {
	private var model: Model
	private var strongReferences: StrongReferences = StrongReferences()
	private var subscriptionManager: SubscriptionManager<Message>!
	private(set) var viewController: UIViewController = UIViewController()
	
	private let updateState: (inout Model, Message) -> [Command<Message>]
	private let computeView: (Model) -> ViewController<Message>
	private let fetchSubscriptions: (Model) -> [Subscription<Message>]
	
	init(_ initial: Model, update: @escaping (inout Model, Message) -> [Command<Message>], view: @escaping (Model) -> ViewController<Message>, subscriptions: @escaping (Model) -> [Subscription<Message>], initialCommands: [Command<Message>] = []) {
		viewController.restorationIdentifier = "objc.io.root"
		model = initial
		self.updateState = update
		self.computeView = view
		self.fetchSubscriptions = subscriptions
		strongReferences = view(model).render(callback: self.asyncSend, change: &viewController)
		self.subscriptionManager = SubscriptionManager(self.asyncSend)
		self.subscriptionManager.update(subscriptions: fetchSubscriptions(model))
		for command in initialCommands {
			interpret(command: command)
		}
	}
	
	func asyncSend(action: Message) {
		DispatchQueue.main.async { [unowned self] in
			self.run(action: action)
		}
	}

	func run(action: Message) {
		assert(Thread.current.isMainThread)
		let commands = updateState(&model, action)
		refresh()
		for command in commands {
			interpret(command: command)
		}
	}

	func interpret(command: Command<Message>) {
		command.run(Context(viewController: viewController, send: self.asyncSend))
	}
	
	func refresh() {
		subscriptionManager.update(subscriptions: fetchSubscriptions(model))
		strongReferences = computeView(model).render(callback: self.asyncSend, change: &viewController)
	}
	
	func encodeRestorableState(_ coder: NSCoder) {
		let jsonData = try! JSONEncoder().encode(model)
		coder.encode(jsonData, forKey: "data")
	}
	
	func decodeRestorableState(_ coder: NSCoder) {
		if let jsonData = coder.decodeObject(forKey: "data") as? Data {
			if let m = try? JSONDecoder().decode(Model.self, from: jsonData) {
				model = m
			}
		}
		refresh()
	}
}
