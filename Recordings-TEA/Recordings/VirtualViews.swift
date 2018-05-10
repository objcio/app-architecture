import UIKit

struct Button<Message> {
    let text: String
    let onTap: Message?
    
    init(text: String, onTap: Message? = nil) {
        self.text = text
        self.onTap = onTap
    }
    
    func map<B>(_ transform: (Message) -> B) -> Button<B> {
        return Button<B>(text: text, onTap: onTap.map(transform))
    }
}

struct TextField<Message> {
    let text: String
    let onChange: ((String?) -> Message)?
    let onEnd: ((String?) -> Message)?
    
    
    init(text: String, onChange: ((String?) -> Message)? = nil, onEnd: ((String?) -> Message)? = nil) {
        self.text = text
        self.onChange = onChange
        self.onEnd = onEnd
    }
    
    func map<B>(_ transform: @escaping (Message) -> B) -> TextField<B> {
        return TextField<B>(text: text, onChange: onChange.map { x in { transform(x($0)) } }, onEnd: onEnd.map { x in { transform(x($0)) } })
    }
}

struct StackView<Message> {
    let views: [View<Message>]
    let axis: UILayoutConstraintAxis
    let distribution: UIStackViewDistribution
    let backgroundColor: UIColor
    
    init(views: [View<Message>], axis: UILayoutConstraintAxis = .vertical, distribution: UIStackViewDistribution = .equalCentering, backgroundColor: UIColor = .white) {
        self.views = views
        self.axis = axis
        self.distribution = distribution
        self.backgroundColor = backgroundColor
    }
    
    func map<B>(_ transform: @escaping (Message) -> B) -> StackView<B> {
        return StackView<B>(views: views.map { view in view.map(transform) }, axis: axis, distribution: distribution, backgroundColor: backgroundColor)
    }
}

struct TableView<Message> {
    let items: [TableViewCell<Message>]
    
    init(items: [TableViewCell<Message>]) {
        self.items = items
    }
    
    func map<B>(_ transform: @escaping (Message) -> B) -> TableView<B> {
        return TableView<B>(items: items.map({ item in item.map(transform) }))
    }
}

struct TableViewCell<Message>: Hashable {
    static func ==(lhs: TableViewCell<Message>, rhs: TableViewCell<Message>) -> Bool {
        return lhs.identity == rhs.identity && lhs.text == rhs.text && lhs.accessory == rhs.accessory
    }
    var hashValue: Int {
        return identity.hashValue
    }
    
    let identity: AnyHashable
    let text: String
    let onSelect: Message?
    let onDelete: Message?
    let accessory: UITableViewCellAccessoryType
    init(identity: AnyHashable, text: String, onSelect: Message?, accessory: UITableViewCellAccessoryType = .none, onDelete: Message?) {
        self.identity = identity
        self.text = text
        self.accessory = accessory
        self.onSelect = onSelect
        self.onDelete = onDelete
    }
    
    func map<B>(_ transform: @escaping (Message) -> B) -> TableViewCell<B> {
        return TableViewCell<B>(identity: identity, text: text, onSelect: onSelect.map(transform), onDelete: onDelete.map(transform))
    }
}

struct Slider<Message> {
    let progress: Float
    let max: Float
    let onChange: ((Float) -> Message)?
    init(progress: Float, max: Float = 1, onChange: ((Float) -> Message)? = nil) {
        self.progress = progress
        self.max = max
        self.onChange = onChange
    }
    
    func map<B>(_ transform: @escaping (Message) -> B) -> Slider<B> {
        return Slider<B>(progress: progress, max: max, onChange: onChange.map { o in { value in transform(o(value)) } })
    }
}

enum BarButtonItem<Message> {
    case none
    case builtin(UIBarButtonItem)
    case system(UIBarButtonSystemItem, action: Message)
    case custom(text: String, action: Message)
    case editButtonItem
    
    func map<B>(_ transform: (Message) -> B) -> BarButtonItem<B> {
        switch self {
        case let .builtin(b):
            return .builtin(b)
        case let .system(i, action: message):
            return .system(i, action: transform(message))
        case let .custom(text: text, action: action):
            return .custom(text: text, action: transform(action))
        case .editButtonItem:
            return .editButtonItem
        case .none:
            return .none
        }
    }
}

struct Label {
    let text: String
    let font: UIFont
}

struct ImageView {
    let image: UIImage?
}

struct Space {
    let width: CGFloat?
    let height: CGFloat?
}

struct ActivityIndicator {
    let style: UIActivityIndicatorViewStyle
}

typealias Constraint = (_ child: UIView, _ parent: UIView) -> NSLayoutConstraint

func equal<Axis, Anchor>(_ keyPath: KeyPath<UIView, Anchor>, _ to: KeyPath<UIView, Anchor>, constant: CGFloat = 0) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return { view, parent in
        view[keyPath: keyPath].constraint(equalTo: parent[keyPath: to], constant: constant)
    }
}

func equal<Axis, Anchor>(_ keyPath: KeyPath<UIView, Anchor>, constant: CGFloat = 0) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, keyPath, constant: constant)
}

func constant(_ keyPath: KeyPath<UIView, NSLayoutDimension>, value: CGFloat = 0) -> Constraint {
    return { view, _ in
        view[keyPath: keyPath].constraint(equalToConstant: value)
    }
}

indirect enum View<Message> {
    case _label(Label)
    case _stackView(StackView<Message>)
    case _button(Button<Message>)
    case _textField(TextField<Message>)
    case _imageView(ImageView)
    case _slider(Slider<Message>)
    case _tableView(TableView<Message>)
    case _space(Space)
    case _activityIndicator(ActivityIndicator)
    case _childViewController(ViewController<Message>)
    case _customLayout([(View<Message>, [Constraint])])
    
    func map<B>(_ transform: @escaping (Message) -> B) -> View<B> {
        switch self {
        case ._button(let b):
            return ._button(b.map(transform))
        case ._textField(let t):
            return ._textField(t.map(transform))
        case let ._label(label):
            return ._label(label)
        case let ._imageView(imageView):
            return ._imageView(imageView)
        case let ._stackView(s):
            return ._stackView(s.map(transform))
        case let ._slider(s):
            return ._slider(s.map(transform))
        case let ._tableView(t):
            return ._tableView(t.map(transform))
        case let ._space(space):
            return ._space(space)
        case let ._activityIndicator(indicator):
            return ._activityIndicator(indicator)
        case let ._childViewController(vc):
            return ._childViewController(vc.map(transform))
        case ._customLayout(let views):
            return ._customLayout(views.map { (v,c) in
                (v.map(transform), c)
            })
        }
    }
}

extension View {
    static func button(text: String, onTap: Message? = nil) -> View {
        return ._button(Button(text: text, onTap: onTap))
    }

    static func textField(text: String, onChange: ((String?) -> Message)? = nil, onEnd: ((String?) -> Message)? = nil) -> View {
        return ._textField(TextField(text: text, onChange: onChange, onEnd: onEnd))
    }
    
    static func label(text: String, font: UIFont) -> View {
        return ._label(Label(text: text, font: font))
    }
    
    static func imageView(image: UIImage? = nil) -> View {
        return ._imageView(ImageView(image: image))
    }
    
    static func stackView(views: [View<Message>], axis: UILayoutConstraintAxis = .vertical, distribution: UIStackViewDistribution = .equalCentering, backgroundColor: UIColor = .white) -> View {
        return ._stackView(StackView(views: views, axis: axis, distribution: distribution, backgroundColor: backgroundColor))
    }
    
    static func slider(progress: Float, max: Float = 1, onChange: ((Float) -> Message)? = nil) -> View {
        return ._slider(Slider(progress: progress, max: max, onChange: onChange))
    }

    static func tableView(items: [TableViewCell<Message>] = []) -> View {
        return ._tableView(TableView(items: items))
    }

    static func space(width: CGFloat? = nil, height: CGFloat? = nil) -> View {
        return ._space(Space(width: width, height: height))
    }
    
    static func activityIndicator(style: UIActivityIndicatorViewStyle = .white) -> View {
        return ._activityIndicator(ActivityIndicator(style: style))
    }
}

