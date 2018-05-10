#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

/// A data structure for describing a layout as a series of nested columns and rows.
public struct Layout {
	/// A rough equivalent to UIStackViewAlignment, minus baseline cases which aren't handled
	public enum Alignment { case leading, trailing, center, fill }
	
	#if os(macOS)
		public typealias Axis = NSUserInterfaceLayoutOrientation
		public typealias View = NSView
		public typealias Guide = NSLayoutGuide
	#else
		public typealias Axis = UILayoutConstraintAxis
		public typealias View = UIView
		public typealias Guide = UILayoutGuide
	#endif
	
	/// Layout is either horizontal or vertical (although any element within the layout may be a layout in the perpendicular direction)
	public let axis: Axis
	
	/// Within the horizontal row or vertical column, layout entities may fill, center or align-leading or align-trailing
	public let align: Alignment
	
	/// The layout may extend to the view bounds or may be limited by the safeAreaMargins or layoutMargins. The safeArea insets supercede the layoutMargins (prior to iOS 11, safeArea is interpreted as UIViewController top/bottom layout guides when laying out within a UIViewController, otherwise it is treated as a synonym for the layoutMargins). This value has no effect on macOS.	
	public let marginEdges: MarginEdges
	
	/// This is the list of views, spaces and sublayouts that will be layed out.
	public let entities: [LayoutEntity]
	
	/// The default constructor assigns all values. In general, it's easier to use the `.horizontal` or `.vertical` constructor where possible.
	public init(axis: Layout.Axis, align: Layout.Alignment = .fill, marginEdges: MarginEdges = .allSafeArea, entities: [LayoutEntity]) {
		self.axis = axis
		self.align = align
		self.entities = entities
		self.marginEdges = marginEdges
	}
	
	/// A convenience constructor for a horizontal layout
	public static func horizontal(align: Layout.Alignment = .fill, marginEdges: MarginEdges = .allSafeArea, _ entities: LayoutEntity...) -> Layout {
		return Layout(axis: .horizontal, align: align, marginEdges: marginEdges, entities: entities)
	}
	
	/// A convenience constructor for a vertical layout
	public static func vertical(align: Layout.Alignment = .fill, marginEdges: MarginEdges = .allSafeArea, _ entities: LayoutEntity...) -> Layout {
		return Layout(axis: .vertical, align: align, marginEdges: marginEdges, entities: entities)
	}
	
	// Used for removing all views from their superviews
	fileprivate func forEachView(_ visit: (View) -> ()) {
		entities.forEach { $0.forEachView(visit) }
	}
}

#if os(macOS)
	extension NSView {
		/// Adds the views contained by `layout` in the arrangment described by the layout to `self`.
		///
		/// - Parameter layout: a set of views and layout descriptions
		public func applyLayout(_ layout: Layout?) {
			applyLayoutToView(view: self, params: layout.map { (layout: $0, bounds: LayoutBounds(view: self, marginEdges: .none)) })
		}
	}
#else
	extension UIView {
		/// Adds the views contained by `layout` in the arrangment described by the layout to `self`.
		///
		/// - Parameter layout: a set of views and layout descriptions
		public func applyLayout(_ layout: Layout?) {
			applyLayoutToView(view: self, params: layout.map { (layout: $0, bounds: LayoutBounds(view: self, marginEdges: $0.marginEdges)) })
		}
	}
	
	extension UIViewController {
		/// Adds the views contained by `layout` in the arrangment described by the layout to `self`.
		///
		/// NOTE: prior to iOS 11, this is required to handle the UIViewController topLayoutGuide and bottomLayoutGuide.
		///
		/// - Parameter layout: a set of views and layout descriptions
		@available(iOS, introduced: 7.0, deprecated: 11.0)
		public func applyLayout(_ layout: Layout?) {
			if let l = layout, l.marginEdges.contains(.topSafeArea) || l.marginEdges.contains(.bottomSafeArea) {
				let wrapper = Layout(
					axis: .vertical,
					align: .fill,
					entities: [LayoutEntity.layout(l, size: nil)]
				)
				applyLayoutToView(view: view!, params: (layout: wrapper, bounds: LayoutBounds(viewController: self, marginEdges: l.marginEdges)))
			} else {
				applyLayoutToView(view: view!, params: layout.map { (layout: $0, bounds: LayoutBounds(viewController: self, marginEdges: $0.marginEdges)) })
			}
		}
	}
#endif

/// The `Layout` describes a series of these `LayoutEntity`s which may be a space, a view or a sublayout. There is also a special `matched` layout which allows a series of "same length" entities.
///
/// - interViewSpace: AppKit and UIKit use an 8 screen unit space as the "standard" space between adjacent views.
/// - space: an arbitrary space between views
/// - view: a view with optional width and height (if not specified, the view will use its "intrinsic" size or will fill the available layout space)
/// - layout: a nested layout which may be parallel or perpedicular to its container and whose size may be specified (like view)
/// - matched: a sequence of alternating "same size" and independent entities (you can use `.space(0)` if you don't want independent entities).
public enum LayoutEntity {
	case space(LayoutDimension)
	case sizedView(Layout.View, LayoutSize?)
	indirect case layout(Layout, size: LayoutSize?)
	indirect case matched(LayoutEntity, [(independent: LayoutEntity, same: LayoutEntity)], priority: LayoutDimension.Priority)
	
	fileprivate func forEachView(_ visit: (Layout.View) -> ()) {
		switch self {
		case .sizedView(let v, _): visit(v)
		case .layout(let l, _): l.forEachView(visit)
		case .matched(let entity, let pairArray, _):
			entity.forEachView(visit)
			pairArray.forEach {
				$0.same.forEachView(visit)
				$0.independent.forEachView(visit)
			}
		default: break
		}
	}
	
	public static func view(_ view: Layout.View) -> LayoutEntity {
		return .sizedView(view, nil)
	}
	
	public static var interViewSpace: LayoutEntity {
		return .space(8)
	}
	
	public static func horizontal(align: Layout.Alignment = .fill, size: LayoutSize? = nil, _ entities: LayoutEntity...) -> LayoutEntity {
		return .layout(Layout(axis: .horizontal, align: align, marginEdges: .none, entities: entities), size: size)
	}
	
	public static func vertical(align: Layout.Alignment = .fill, size: LayoutSize? = nil, _ entities: LayoutEntity...) -> LayoutEntity {
		return .layout(Layout(axis: .vertical, align: align, marginEdges: .none, entities: entities), size: size)
	}
	
	public static func matchedPair(_ left: LayoutEntity, _ right: LayoutEntity, separator: LayoutEntity = .interViewSpace, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutEntity {
		return .matched(left, [(independent: separator, same: right)], priority: priority)
	}
}

/// A `LayoutSize` is the combination of both length (size of a layout object in the direction of layout) or breadth (size of a layout object perpendicular to the layout direction). If the length includes a ratio, it is relative to the parent container but the breadth can be relative to the length, allowing for specifying an aspect ratio.
public struct LayoutSize {
	public let length: LayoutDimension?
	public let breadth: (LayoutDimension, relativeToLength: Bool)?
	
	public init(length: LayoutDimension? = nil, breadth: (LayoutDimension, relativeToLength: Bool)? = nil) {
		self.length = length
		self.breadth = breadth
	}
	
	public static func lengthLessThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutSize {
		return LayoutSize(length: LayoutDimension(ratio: ratio, constant: constant, relationship: .lessThanOrEqual, priority: priority))
	}
	
	public static func lengthGreaterThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutSize {
		return LayoutSize(length: LayoutDimension(ratio: ratio, constant: constant, relationship: .greaterThanOrEqual, priority: priority))
	}
	
	public static func lengthEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutSize {
		return LayoutSize(length: LayoutDimension(ratio: ratio, constant: constant, relationship: .equal, priority: priority))
	}
	
	public static var fillRemainingLength: LayoutSize {
		return lengthGreaterThanOrEqualTo(ratio: 1.0, constant: 0, priority: LayoutDimension.PriorityDefaultLow)
	}
	
	public static func breadthLessThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired, relativeToWidth: Bool = false) -> LayoutSize {
		return LayoutSize(breadth: (LayoutDimension(ratio: ratio, constant: constant, relationship: .lessThanOrEqual, priority: priority), relativeToWidth))
	}
	
	public static func breadthGreaterThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired, relativeToWidth: Bool = false) -> LayoutSize {
		return LayoutSize(breadth: (LayoutDimension(ratio: ratio, constant: constant, relationship: .greaterThanOrEqual, priority: priority), relativeToWidth))
	}
	
	public static func breadthEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired, relativeToWidth: Bool = false) -> LayoutSize {
		return LayoutSize(breadth: (LayoutDimension(ratio: ratio, constant: constant, relationship: .equal, priority: priority), relativeToWidth))
	}
}

/// When length (size of a layout object in the direction of layout) or breadth (size of a layout object perpendicular to the layout direction) is specified, it can be specified:
///	* relative to the parent container (ratio)
///	* in raw screen units (constant)
/// The greater/less than and priority can also be specified.
public struct LayoutDimension: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
	public typealias FloatLiteralType = Double
	public typealias IntegerLiteralType = Int
	
	#if os(macOS)
		public typealias Relation = NSLayoutConstraint.Relation
		public typealias Priority = NSLayoutConstraint.Priority
		#if swift(>=4)
			public static let PriorityRequired = NSLayoutConstraint.Priority.required
			public static let PriorityDefaultLow = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultLow.rawValue * 0.875)
			public static let PriorityDefaultMid = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.required.rawValue * 0.5)
			public static let PriorityDefaultHigh = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultHigh.rawValue * 1.125)
		#else
			public static let PriorityRequired = NSLayoutPriorityRequired
			public static let PriorityDefaultLow = NSLayoutPriorityDefaultLow * 0.875
			public static let PriorityDefaultMid = NSLayoutPriorityRequired * 0.5
			public static let PriorityDefaultHigh = NSLayoutPriorityDefaultHigh * 1.125
		#endif
	#else
		public typealias Relation = NSLayoutRelation
		public typealias Priority = UILayoutPriority
		#if swift(>=4)
			public static let PriorityRequired = UILayoutPriority.required
			public static let PriorityDefaultLow = UILayoutPriority(rawValue: UILayoutPriority.defaultLow.rawValue * 0.875)
			public static let PriorityDefaultMid = UILayoutPriority(rawValue: UILayoutPriority.required.rawValue * 0.5)
			public static let PriorityDefaultHigh = UILayoutPriority(rawValue: UILayoutPriority.defaultHigh.rawValue * 1.125)
		#else
			public static let PriorityRequired = UILayoutPriorityRequired
			public static let PriorityDefaultLow = UILayoutPriorityDefaultLow * 0.875
			public static let PriorityDefaultMid = UILayoutPriorityRequired * 0.5
			public static let PriorityDefaultHigh = UILayoutPriorityDefaultHigh * 1.125
		#endif
	#endif
	
	
	
	public let ratio: CGFloat
	public let constant: CGFloat
	public let relationship: Relation
	public let priority: LayoutDimension.Priority
	public init(ratio: CGFloat = 0, constant: CGFloat = 0, relationship: LayoutDimension.Relation = .equal, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) {
		self.ratio = ratio
		self.constant = constant
		self.relationship = relationship
		self.priority = priority
	}
	
	public init(floatLiteral value: Double) {
		self.init(constant: CGFloat(value))
	}
	
	public init(integerLiteral value: Int) {
		self.init(constant: CGFloat(value))
	}
	
	public static func lessThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutDimension {
		return LayoutDimension(ratio: ratio, constant: constant, relationship: .lessThanOrEqual, priority: priority)
	}
	
	public static func greaterThanOrEqualTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutDimension {
		return LayoutDimension(ratio: ratio, constant: constant, relationship: .greaterThanOrEqual, priority: priority)
	}
	
	public static func equalTo(ratio: CGFloat = 0, constant: CGFloat = 0, priority: LayoutDimension.Priority = LayoutDimension.PriorityRequired) -> LayoutDimension {
		return LayoutDimension(ratio: ratio, constant: constant, relationship: .equal, priority: priority)
	}
	
	public static var fillRemaining: LayoutDimension {
		return greaterThanOrEqualTo(constant: 0, priority: LayoutDimension.PriorityDefaultHigh)
	}
}

// This type handles a combination of `layoutMargin` and `safeAreaMargin` inset edges. If a `safeArea` edge is specified, it will be used instead of `layout` edge.
public struct MarginEdges: OptionSet {
	public static var none: MarginEdges { return MarginEdges(rawValue: 0) }
	public static var topLayout: MarginEdges { return MarginEdges(rawValue: 1) }
	public static var leadingLayout: MarginEdges { return MarginEdges(rawValue: 2) }
	public static var bottomLayout: MarginEdges { return MarginEdges(rawValue: 4) }
	public static var trailingLayout: MarginEdges { return MarginEdges(rawValue: 8) }
	public static var topSafeArea: MarginEdges { return MarginEdges(rawValue: 16) }
	public static var leadingSafeArea: MarginEdges { return MarginEdges(rawValue: 32) }
	public static var bottomSafeArea: MarginEdges { return MarginEdges(rawValue: 64) }
	public static var trailingSafeArea: MarginEdges { return MarginEdges(rawValue: 128) }
	public static var allLayout: MarginEdges { return [.topLayout, .leadingLayout, .bottomLayout, .trailingLayout] }
	public static var allSafeArea: MarginEdges { return [.topSafeArea, .leadingSafeArea, .bottomSafeArea, .trailingSafeArea] }
	public let rawValue: UInt
	public init(rawValue: UInt) {
		self.rawValue = rawValue
	}
}

// DEBUGGING TIP:
// As of Xcode 8, the "Debug View Hierarchy" option does not show layout guides, making debugging of constraints involving layout guides tricky. To aid debugging in these cases, set the following condition to `true && DEBUG` and CwlLayout will create views instead of layout guides.
// Otherwise, you can set this to `false && DEBUG`.
#if true && DEBUG
	fileprivate typealias LayoutBox = Layout.View
	
	extension Layout.View {
		fileprivate func addLayoutBox(_ layoutBox: LayoutBox) {
			layoutBox.translatesAutoresizingMaskIntoConstraints = false
			self.addSubview(layoutBox)
		}
		fileprivate func removeLayoutBox(_ layoutBox: LayoutBox) {
			layoutBox.removeFromSuperview()
		}
	}
#else
	fileprivate typealias LayoutBox = Layout.Guide
	
	extension Layout.View {
		fileprivate func addLayoutBox(_ layoutBox: LayoutBox) {
			self.addLayoutGuide(layoutBox)
		}
		fileprivate func removeLayoutBox(_ layoutBox: LayoutBox) {
			self.removeLayoutGuide(layoutBox)
		}
	}
#endif

/// LayoutBounds are used internally to capture a set of guides and anchors. On the Mac, these are merely copied from a single NSLayoutGuide or an NSView. On iOS, these may be copied from a blend of UIViewController top/bottomLayoutGuides, safeAreaLayoutGuides, layoutMarginsGuides or a UIView.
fileprivate struct LayoutBounds {
	var leading: NSLayoutXAxisAnchor
	var top: NSLayoutYAxisAnchor
	var trailing: NSLayoutXAxisAnchor
	var bottom: NSLayoutYAxisAnchor
	var width: NSLayoutDimension
	var height: NSLayoutDimension
	var centerX: NSLayoutXAxisAnchor
	var centerY: NSLayoutYAxisAnchor
	
	fileprivate init(box: LayoutBox) {
		leading = box.leadingAnchor
		top = box.topAnchor
		trailing = box.trailingAnchor
		bottom = box.bottomAnchor
		width = box.widthAnchor
		height = box.heightAnchor
		centerX = box.centerXAnchor
		centerY = box.centerYAnchor
	}
	
	#if os(iOS)
		@available(iOS, introduced: 7.0, deprecated: 11.0)
		fileprivate init(viewController: UIViewController, marginEdges: MarginEdges) {
			let view = viewController.view!
			leading = marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout) ? view.layoutMarginsGuide.leadingAnchor : view.leadingAnchor
			top = marginEdges.contains(.topSafeArea) ? viewController.topLayoutGuide.bottomAnchor : (marginEdges.contains(.topLayout) ? view.layoutMarginsGuide.topAnchor : view.topAnchor)
			trailing = marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.trailingAnchor : view.trailingAnchor
			bottom = marginEdges.contains(.bottomSafeArea) ? viewController.bottomLayoutGuide.topAnchor : (marginEdges.contains(.bottomLayout) ? view.layoutMarginsGuide.bottomAnchor : view.bottomAnchor)
			width = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.widthAnchor : view.widthAnchor
			height = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.heightAnchor : view.heightAnchor
			centerX = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.centerXAnchor : view.centerXAnchor
			centerY = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.centerYAnchor : view.centerYAnchor
		}
		
		fileprivate init(view: Layout.View, marginEdges: MarginEdges) {
			if #available(iOS 11.0, *) {
				#if swift(>=4)
					leading = marginEdges.contains(.leadingSafeArea) ? view.safeAreaLayoutGuide.leadingAnchor : (marginEdges.contains(.leadingLayout) ? view.layoutMarginsGuide.leadingAnchor : view.leadingAnchor)
					top = marginEdges.contains(.topSafeArea) ? view.safeAreaLayoutGuide.topAnchor : (marginEdges.contains(.topLayout) ? view.layoutMarginsGuide.topAnchor : view.topAnchor)
					trailing = marginEdges.contains(.trailingSafeArea) ? view.safeAreaLayoutGuide.trailingAnchor : (marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.trailingAnchor : view.trailingAnchor)
					bottom = marginEdges.contains(.bottomSafeArea) ? view.safeAreaLayoutGuide.bottomAnchor : (marginEdges.contains(.bottomLayout) ? view.layoutMarginsGuide.bottomAnchor : view.bottomAnchor)
					width = (marginEdges.contains(.leadingSafeArea) && marginEdges.contains(.trailingSafeArea)) ? view.safeAreaLayoutGuide.widthAnchor : (marginEdges.contains(.leadingLayout) && marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.widthAnchor : view.widthAnchor)
					height = (marginEdges.contains(.leadingSafeArea) && marginEdges.contains(.trailingSafeArea)) ? view.safeAreaLayoutGuide.heightAnchor : (marginEdges.contains(.leadingLayout) && marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.heightAnchor : view.heightAnchor)
					centerX = (marginEdges.contains(.leadingSafeArea) && marginEdges.contains(.trailingSafeArea)) ? view.safeAreaLayoutGuide.centerXAnchor : (marginEdges.contains(.leadingLayout) && marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.centerXAnchor : view.centerXAnchor)
					centerY = (marginEdges.contains(.leadingSafeArea) && marginEdges.contains(.trailingSafeArea)) ? view.safeAreaLayoutGuide.centerYAnchor : (marginEdges.contains(.leadingLayout) && marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.centerYAnchor : view.centerYAnchor)
				#else
					leading = marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout) ? view.layoutMarginsGuide.leadingAnchor : view.leadingAnchor
					top = marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout) ? view.layoutMarginsGuide.topAnchor : view.topAnchor
					trailing = marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.trailingAnchor : view.trailingAnchor
					bottom = marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout) ? view.layoutMarginsGuide.bottomAnchor : view.bottomAnchor
					width = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.widthAnchor : view.widthAnchor
					height = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.heightAnchor : view.heightAnchor
					centerX = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.centerXAnchor : view.centerXAnchor
					centerY = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.centerYAnchor : view.centerYAnchor
				#endif
			} else {
				leading = marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout) ? view.layoutMarginsGuide.leadingAnchor : view.leadingAnchor
				top = marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout) ? view.layoutMarginsGuide.topAnchor : view.topAnchor
				trailing = marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout) ? view.layoutMarginsGuide.trailingAnchor : view.trailingAnchor
				bottom = marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout) ? view.layoutMarginsGuide.bottomAnchor : view.bottomAnchor
				width = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.widthAnchor : view.widthAnchor
				height = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.heightAnchor : view.heightAnchor
				centerX = (marginEdges.contains(.leadingSafeArea) || marginEdges.contains(.leadingLayout)) && (marginEdges.contains(.trailingSafeArea) || marginEdges.contains(.trailingLayout)) ? view.layoutMarginsGuide.centerXAnchor : view.centerXAnchor
				centerY = (marginEdges.contains(.topSafeArea) || marginEdges.contains(.topLayout)) && (marginEdges.contains(.bottomSafeArea) || marginEdges.contains(.bottomLayout)) ? view.layoutMarginsGuide.centerYAnchor : view.centerYAnchor
			}
		}
	#else
		fileprivate init(view: Layout.View, marginEdges: MarginEdges) {
			leading = view.leadingAnchor
			top = view.topAnchor
			trailing = view.trailingAnchor
			bottom = view.bottomAnchor
			width = view.widthAnchor
			height = view.heightAnchor
			centerX = view.centerXAnchor
			centerY = view.centerYAnchor
		}
	#endif
}

fileprivate class ViewLayoutStorage: NSObject {
	let layout: Layout
	var constraints: [NSLayoutConstraint] = []
	var boxes: [LayoutBox] = []
	
	init(layout: Layout) {
		self.layout = layout
	}
}

fileprivate var associatedLayoutKey = NSObject()
fileprivate func setLayout(_ newValue: ViewLayoutStorage?, for object: Layout.View) {
	objc_setAssociatedObject(object, &associatedLayoutKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
}
fileprivate func getLayout(for view: Layout.View) -> ViewLayoutStorage? {
	return objc_getAssociatedObject(view, &associatedLayoutKey) as? ViewLayoutStorage
}

fileprivate func applyLayoutToView(view: Layout.View, params: (layout: Layout, bounds: LayoutBounds)?) {
	if let previous = getLayout(for: view) {
		for constraint in previous.constraints {
			constraint.isActive = false
		}
		for box in previous.boxes {
			view.removeLayoutBox(box)
		}
		previous.layout.forEachView { $0.removeFromSuperview() }
	}
	
	if let (layout, bounds) = params {
		let storage = ViewLayoutStorage(layout: layout)
		layout.add(to: view, containerBounds: bounds, storage: storage)
		setLayout(storage, for: view)
	}
}

fileprivate struct LayoutState {
	let view: Layout.View
	let storage: ViewLayoutStorage
	
	var dimension: LayoutDimension? = nil
	var previousEntityBounds: LayoutBounds? = nil
	var containerBounds: LayoutBounds
	
	init(containerBounds: LayoutBounds, in view: Layout.View, storage: ViewLayoutStorage) {
		self.containerBounds = containerBounds
		self.view = view
		self.storage = storage
	}
}

extension Layout {
	fileprivate func constrain(bounds: LayoutBounds, leading: LayoutDimension, length: LayoutDimension?, breadth: (LayoutDimension, Bool)?, state: inout LayoutState) {
		if axis == .horizontal {
			let leadingAnchor = bounds.leading
			let preceedingAnchor = state.containerBounds.leading
			let leadingConstraint: NSLayoutConstraint
			switch leading.relationship {
			case .equal: leadingConstraint = leadingAnchor.constraint(equalTo: preceedingAnchor, constant: leading.constant)
			case .lessThanOrEqual: leadingConstraint = leadingAnchor.constraint(lessThanOrEqualTo: preceedingAnchor, constant: leading.constant)
			case .greaterThanOrEqual: leadingConstraint = leadingAnchor.constraint(greaterThanOrEqualTo: preceedingAnchor, constant: leading.constant)
			}
			leadingConstraint.priority = leading.priority
			state.storage.constraints.append(leadingConstraint)
			leadingConstraint.isActive = true
			
			if let l = length {
				let widthAnchor = bounds.width
				let widthConstraint: NSLayoutConstraint
				switch l.relationship {
				case .equal: widthConstraint = widthAnchor.constraint(equalTo: state.containerBounds.width, multiplier: l.ratio, constant: l.constant)
				case .lessThanOrEqual: widthConstraint = widthAnchor.constraint(lessThanOrEqualTo: state.containerBounds.width, multiplier: l.ratio, constant: l.constant)
				case .greaterThanOrEqual: widthConstraint = widthAnchor.constraint(greaterThanOrEqualTo: state.containerBounds.width, multiplier: l.ratio, constant: l.constant)
				}
				widthConstraint.priority = l.priority
				state.storage.constraints.append(widthConstraint)
				widthConstraint.isActive = true
			}
			
			if let b = breadth {
				let heightAnchor = bounds.height
				let secondAnchor = b.1 ? bounds.width : state.containerBounds.height
				let heightConstraint: NSLayoutConstraint
				switch b.0.relationship {
				case .equal: heightConstraint = heightAnchor.constraint(equalTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				case .lessThanOrEqual: heightConstraint = heightAnchor.constraint(lessThanOrEqualTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				case .greaterThanOrEqual: heightConstraint = heightAnchor.constraint(greaterThanOrEqualTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				}
				heightConstraint.priority = b.0.priority
				state.storage.constraints.append(heightConstraint)
				heightConstraint.isActive = true
			}
			
			switch self.align {
			case .leading:
				let top = bounds.top.constraint(equalTo: state.containerBounds.top)
				let bottom = bounds.bottom.constraint(equalTo: state.containerBounds.bottom)
				let bottom2 = bounds.bottom.constraint(lessThanOrEqualTo: state.containerBounds.bottom)
				top.priority = LayoutDimension.PriorityRequired
				bottom.priority = LayoutDimension.PriorityDefaultLow
				bottom2.priority = LayoutDimension.PriorityDefaultHigh
				top.isActive = true
				bottom.isActive = true
				bottom2.isActive = true
				state.storage.constraints.append(top)
				state.storage.constraints.append(bottom)
				state.storage.constraints.append(bottom2)
			case .trailing:
				let top = bounds.top.constraint(equalTo: state.containerBounds.top)
				let top2 = bounds.top.constraint(greaterThanOrEqualTo: state.containerBounds.top)
				let bottom = bounds.bottom.constraint(equalTo: state.containerBounds.bottom)
				top.priority = LayoutDimension.PriorityDefaultLow
				top2.priority = LayoutDimension.PriorityDefaultHigh
				bottom.priority = LayoutDimension.PriorityRequired
				top.isActive = true
				top2.isActive = true
				bottom.isActive = true
				state.storage.constraints.append(top)
				state.storage.constraints.append(top2)
				state.storage.constraints.append(bottom)
			case .center:
				let center = bounds.centerY.constraint(equalTo: state.containerBounds.centerY)
				center.priority = LayoutDimension.PriorityRequired
				center.isActive = true
				state.storage.constraints.append(center)
				let height = bounds.height.constraint(equalTo: state.containerBounds.height)
				height.priority = LayoutDimension.PriorityDefaultLow
				height.isActive = true
				state.storage.constraints.append(height)
			case .fill:
				let top = bounds.top.constraint(equalTo: state.containerBounds.top)
				let bottom = bounds.bottom.constraint(equalTo: state.containerBounds.bottom)
				top.priority = LayoutDimension.PriorityDefaultHigh
				bottom.priority = LayoutDimension.PriorityDefaultHigh
				top.isActive = true
				bottom.isActive = true
				state.storage.constraints.append(top)
				state.storage.constraints.append(bottom)
			}
			
			state.containerBounds.leading = bounds.trailing
		} else {
			let leadingAnchor = bounds.top
			let preceedingAnchor = state.containerBounds.top
			let leadingConstraint: NSLayoutConstraint
			switch leading.relationship {
			case .equal: leadingConstraint = leadingAnchor.constraint(equalTo: preceedingAnchor, constant: leading.constant)
			case .lessThanOrEqual: leadingConstraint = leadingAnchor.constraint(lessThanOrEqualTo: preceedingAnchor, constant: leading.constant)
			case .greaterThanOrEqual: leadingConstraint = leadingAnchor.constraint(greaterThanOrEqualTo: preceedingAnchor, constant: leading.constant)
			}
			leadingConstraint.priority = leading.priority
			state.storage.constraints.append(leadingConstraint)
			leadingConstraint.isActive = true
			
			if let l = length {
				let heightAnchor = bounds.height
				let heightConstraint: NSLayoutConstraint
				switch l.relationship {
				case .equal: heightConstraint = heightAnchor.constraint(equalTo: state.containerBounds.height, multiplier: l.ratio, constant: l.constant)
				case .lessThanOrEqual: heightConstraint = heightAnchor.constraint(lessThanOrEqualTo: state.containerBounds.height, multiplier: l.ratio, constant: l.constant)
				case .greaterThanOrEqual: heightConstraint = heightAnchor.constraint(greaterThanOrEqualTo: state.containerBounds.height, multiplier: l.ratio, constant: l.constant)
				}
				heightConstraint.priority = l.priority
				state.storage.constraints.append(heightConstraint)
				heightConstraint.isActive = true
			}
			
			if let b = breadth {
				let widthAnchor = bounds.width
				let secondAnchor = b.1 ? bounds.height : state.containerBounds.width
				let widthConstraint: NSLayoutConstraint
				switch b.0.relationship {
				case .equal: widthConstraint = widthAnchor.constraint(equalTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				case .lessThanOrEqual: widthConstraint = widthAnchor.constraint(lessThanOrEqualTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				case .greaterThanOrEqual: widthConstraint = widthAnchor.constraint(greaterThanOrEqualTo: secondAnchor, multiplier: b.0.ratio, constant: b.0.constant)
				}
				widthConstraint.priority = b.0.priority
				state.storage.constraints.append(widthConstraint)
				widthConstraint.isActive = true
			}
			
			switch self.align {
			case .leading:
				let leading = bounds.leading.constraint(equalTo: state.containerBounds.leading)
				let trailing = bounds.trailing.constraint(equalTo: state.containerBounds.trailing)
				let trailing2 = bounds.trailing.constraint(lessThanOrEqualTo: state.containerBounds.trailing)
				leading.priority = LayoutDimension.PriorityRequired
				trailing.priority = LayoutDimension.PriorityDefaultLow
				trailing2.priority = LayoutDimension.PriorityDefaultHigh
				leading.isActive = true
				trailing.isActive = true
				trailing2.isActive = true
				state.storage.constraints.append(leading)
				state.storage.constraints.append(trailing)
				state.storage.constraints.append(trailing2)
			case .trailing:
				let leading = bounds.leading.constraint(equalTo: state.containerBounds.leading)
				let leading2 = bounds.leading.constraint(greaterThanOrEqualTo: state.containerBounds.leading)
				let trailing = bounds.trailing.constraint(equalTo: state.containerBounds.trailing)
				leading.priority = LayoutDimension.PriorityDefaultLow
				leading2.priority = LayoutDimension.PriorityDefaultHigh
				trailing.priority = LayoutDimension.PriorityRequired
				leading.isActive = true
				leading2.isActive = true
				trailing.isActive = true
				state.storage.constraints.append(leading)
				state.storage.constraints.append(leading2)
				state.storage.constraints.append(trailing)
			case .center:
				let center = bounds.centerX.constraint(equalTo: state.containerBounds.centerX)
				center.priority = LayoutDimension.PriorityRequired
				center.isActive = true
				state.storage.constraints.append(center)
				let width = bounds.width.constraint(equalTo: state.containerBounds.width)
				width.priority = LayoutDimension.PriorityDefaultLow
				width.isActive = true
				state.storage.constraints.append(width)
			case .fill:
				let leading = bounds.leading.constraint(equalTo: state.containerBounds.leading)
				let trailing = bounds.trailing.constraint(equalTo: state.containerBounds.trailing)
				leading.priority = LayoutDimension.PriorityDefaultHigh
				trailing.priority = LayoutDimension.PriorityDefaultHigh
				leading.isActive = true
				trailing.isActive = true
				state.storage.constraints.append(leading)
				state.storage.constraints.append(trailing)
			}
			
			state.containerBounds.top = bounds.bottom
		}
	}
	
	@discardableResult
	fileprivate func layout(entity: LayoutEntity, state: inout LayoutState, needDimensionAnchor: Bool = false) -> NSLayoutDimension? {
		switch entity {
		case .space(let dimension):
			if let d = state.dimension, (d.ratio != 0 || d.constant != 0) {
				let box = LayoutBox()
				state.view.addLayoutBox(box)
				state.storage.boxes.append(box)
				constrain(bounds: LayoutBounds(box: box), leading: LayoutDimension(), length: d, breadth: nil, state: &state)
				state.previousEntityBounds = nil
			}
			if dimension.ratio != 0 || needDimensionAnchor {
				let box = LayoutBox()
				state.view.addLayoutBox(box)
				state.storage.boxes.append(box)
				constrain(bounds: LayoutBounds(box: box), leading: LayoutDimension(), length: dimension, breadth: nil, state: &state)
				return axis == .horizontal ? box.widthAnchor : box.heightAnchor
			}
			state.dimension = dimension
			return nil
		case .layout(let l, let size):
			let box = LayoutBox()
			state.view.addLayoutBox(box)
			state.storage.boxes.append(box)
			let bounds = LayoutBounds(box: box)
			l.add(to: state.view, containerBounds: bounds, storage: state.storage)
			constrain(bounds: bounds, leading: state.dimension ?? LayoutDimension(), length: size?.length, breadth: size?.breadth, state: &state)
			state.dimension = nil
			state.previousEntityBounds = bounds
			return needDimensionAnchor ? (axis == .horizontal ? box.widthAnchor : box.heightAnchor) : nil
		case .matched(let first, let pairs, let priority):
			if needDimensionAnchor {
				let box = LayoutBox()
				state.view.addLayoutBox(box)
				state.storage.boxes.append(box)
				var subState = LayoutState(containerBounds: state.containerBounds, in: state.view, storage: state.storage)
				layout(entity: entity, state: &subState)
				state.dimension = nil
				state.previousEntityBounds = LayoutBounds(box: box)
				return axis == .horizontal ? box.widthAnchor : box.heightAnchor
			} else {
				let first = layout(entity: first, state: &state, needDimensionAnchor: true)!
				for p in pairs {
					layout(entity: p.independent, state: &state)
					let match = layout(entity: p.same, state: &state, needDimensionAnchor: true)!
					let constraint = match.constraint(equalTo: first)
					state.storage.constraints.append(constraint)
					constraint.priority = priority
					constraint.isActive = true
				}
				return nil
			}
		case .sizedView(let v, let size):
			v.translatesAutoresizingMaskIntoConstraints = false
			state.view.addSubview(v)
			constrain(bounds: LayoutBounds(view: v, marginEdges: .none), leading: state.dimension ?? LayoutDimension(), length: size?.length, breadth: size?.breadth, state: &state)
			state.dimension = nil
			state.previousEntityBounds = LayoutBounds(view: v, marginEdges: .none)
			return needDimensionAnchor ? (axis == .horizontal ? v.widthAnchor : v.heightAnchor) : nil
		}
	}
	
	fileprivate func add(to view: Layout.View, containerBounds: LayoutBounds, storage: ViewLayoutStorage) {
		var state = LayoutState(containerBounds: containerBounds, in: view, storage: storage)
		for entity in entities {
			layout(entity: entity, state: &state)
		}
		if let previous = state.previousEntityBounds {
			switch axis {
			case .horizontal:
				let trailingAnchor = previous.trailing
				let boundsTrailingAnchor = state.containerBounds.trailing
				let trailingConstraint: NSLayoutConstraint
				let trailing = state.dimension ?? LayoutDimension()
				
				// NOTE: we must invert the relationship since we're laying out backwards
				switch trailing.relationship {
				case .equal: trailingConstraint = trailingAnchor.constraint(equalTo: boundsTrailingAnchor, constant: -trailing.constant)
				case .lessThanOrEqual: trailingConstraint = trailingAnchor.constraint(greaterThanOrEqualTo: boundsTrailingAnchor, constant: -trailing.constant)
				case .greaterThanOrEqual: trailingConstraint = trailingAnchor.constraint(lessThanOrEqualTo: boundsTrailingAnchor, constant: -trailing.constant)
				}
				
				trailingConstraint.priority = trailing.priority
				state.storage.constraints.append(trailingConstraint)
				trailingConstraint.isActive = true
			case .vertical:
				let trailingAnchor = previous.bottom
				let boundsTrailingAnchor = state.containerBounds.bottom
				let trailingConstraint: NSLayoutConstraint
				let trailing = state.dimension ?? LayoutDimension()
				
				// NOTE: we must invert the relationship since we're laying out backwards
				switch trailing.relationship {
				case .equal: trailingConstraint = trailingAnchor.constraint(equalTo: boundsTrailingAnchor, constant: -trailing.constant)
				case .lessThanOrEqual: trailingConstraint = trailingAnchor.constraint(greaterThanOrEqualTo: boundsTrailingAnchor, constant: -trailing.constant)
				case .greaterThanOrEqual: trailingConstraint = trailingAnchor.constraint(lessThanOrEqualTo: boundsTrailingAnchor, constant: -trailing.constant)
				}
				
				trailingConstraint.priority = trailing.priority
				state.storage.constraints.append(trailingConstraint)
				trailingConstraint.isActive = true
			}
		}
	}
}

