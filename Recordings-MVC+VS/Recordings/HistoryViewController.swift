import UIKit

class HistoryViewController: UIViewController {
	var overlayWindow: UIWindow
	var slider: UISlider
	var label: UILabel
	
	var storeHistory: [Data] = []
	var viewStateHistory: [Data] = []
	var historyIndex: Int?

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		overlayWindow = UIWindow()
		slider = UISlider()
		label = UILabel()
		
		super.init(nibName: nil, bundle: nil)
		
		// Force a view load
		_ = self.view
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func setWindowFrame() {
		let screenBounds = UIScreen.main.bounds
		let height: CGFloat = 16 + 40
		overlayWindow.frame = CGRect(x: screenBounds.origin.x, y: screenBounds.origin.y + screenBounds.size.height - height, width: screenBounds.size.width, height: height)
	}
	
	override func loadView() {
		setWindowFrame()
		overlayWindow.backgroundColor = .clear
		overlayWindow.isOpaque = false
		overlayWindow.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		overlayWindow.rootViewController = self
		
		let view = UIView(frame: overlayWindow.bounds)
		
		slider.frame = CGRect(x: 0, y: 0, width: overlayWindow.bounds.size.width, height: 40)
		slider.autoresizingMask = [.flexibleWidth]
		slider.addTarget(self, action: #selector(sliderAction(_:)), for: .valueChanged)
		slider.minimumValue = 0
		slider.maximumValue = 1
		slider.value = 1
		slider.isEnabled = false
		
		label.textAlignment = .center
		label.textColor = .white
		
		view.backgroundColor = UIColor(white: 0, alpha: 0.5)

		self.view = view
		
		applyLayout()
		
		overlayWindow.makeKeyAndVisible()
	}
	
	func applyLayout() {
		setWindowFrame()
		view.applyLayout(.vertical(marginEdges: .none,
			.interViewSpace,
			.horizontal(
				.space(20),
				.view(slider),
				.interViewSpace,
				.sizedView(label, .lengthGreaterThanOrEqualTo(constant: 50)),
				.space(20)
			),
			.interViewSpace
		))
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if let documentData = try? DocumentStore.shared.serialized() {
			storeHistory.append(documentData)
		}
		if let viewStateData = try? ViewStateStore.shared.serialized() {
			viewStateHistory.append(viewStateData)
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: nil, object: DocumentStore.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: nil, object: ViewStateStore.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationChanged(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)

		updateDisplay(userAction: false)
	}
	
	@objc func deviceOrientationChanged(_ notification: Notification) {
		setWindowFrame()
		view.frame = overlayWindow.bounds
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		if notification.name == notifyingStoreReloadNotification || notification.userInfo?[notifyingStoreSideEffectKey] as? Bool == true {
			updateDisplay(userAction: false)
			return
		}
		
		let storeData = try? DocumentStore.shared.serialized()
		let viewStateData = try? ViewStateStore.shared.serialized()

		if let sd = storeData, let vsd = viewStateData {
			if let truncateIndex = historyIndex, storeHistory.indices.contains(truncateIndex) {
				storeHistory.removeSubrange((truncateIndex + 1)..<storeHistory.endIndex)
			}
			storeHistory.append(sd)
			
			if let truncateIndex = historyIndex, viewStateHistory.indices.contains(truncateIndex) {
				viewStateHistory.removeSubrange((truncateIndex + 1)..<viewStateHistory.endIndex)
			}
			viewStateHistory.append(vsd)

			historyIndex = nil
		}
		
		updateDisplay(userAction: true)
	}
	
	func updateDisplay(userAction: Bool) {
		let hc = storeHistory.count
		let hi = (historyIndex ?? hc - 1) + 1
		label.text = "\(hi)/\(hc)"
		
		if userAction {
			slider.maximumValue = Float(hc)
			slider.minimumValue = 0 + (hc > 1 ? 1 : 0)
			if Int(round(slider.value)) - 1 != hi {
				slider.value = Float(hi)
			}
			slider.isEnabled = hc > 1
		}
	}
	
	@objc func sliderAction(_ sender: Any?) {
		if sender as? UISlider === slider {
			let hi = Int(round(slider.value)) - 1
			if historyIndex != hi, storeHistory.indices.contains(hi) {
				historyIndex = hi
				ViewStateStore.shared.loadWithoutNotifying(jsonData: viewStateHistory[hi])
				DocumentStore.shared.loadWithoutNotifying(jsonData: storeHistory[hi])
				ViewStateStore.shared.postReloadNotification(jsonData: viewStateHistory[hi])
				DocumentStore.shared.postReloadNotification(jsonData: storeHistory[hi])
			}
		}
	}
}
