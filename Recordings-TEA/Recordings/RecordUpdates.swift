import Foundation

extension RecordState {
	enum Message: Equatable {
		case stop
		case save(name: String?)
		case progressChanged(TimeInterval?)
	}
	
	mutating func update<C>(_ message: Message) -> [C]
		where C: CommandProtocol, C.Message == Message {
		switch message {
		case .stop:
			return [
				C.stopRecorder(recorder),
				C.modalTextAlert(title: .saveRecording, accept: .save, cancel: .cancel, placeholder: .nameForRecording, submit: { .save(name: $0) })
			]
		case let .save(name: name):
			guard let name = name, !name.isEmpty else {
				// show that we can't save...
				return []
			}
			return [C.saveRecording(name: name, folder: folder, url: recorder.url)]
		case let .progressChanged(value):
			if let v = value {
				self.duration = v
			}
			return []
		}
	}
}

protocol CommandProtocol {
	associatedtype Message
	static func stopRecorder(_ r: Recorder) -> Self
	static func modalTextAlert(title: String, accept: String, cancel: String, placeholder: String, submit: @escaping (String?) -> Message) -> Self
	static func saveRecording(name: String, folder: Folder, url: URL) -> Self
}

extension Command: CommandProtocol { }

enum CommandEnum<Message>: CommandProtocol {
	case _stopRecorder(Recorder)
	case _modalTextAlert(title: String, accept: String, cancel: String, placeholder: String, submit: (String?) -> Message)
	case _saveRecording(name: String, folder: Folder, url: URL)


	static func stopRecorder(_ r: Recorder) -> CommandEnum<Message> {
		return _stopRecorder(r)
	}

	static func modalTextAlert(title: String, accept: String, cancel: String, placeholder: String, submit: @escaping (String?) -> Message) -> CommandEnum<Message> {
		return ._modalTextAlert(title: title, accept: accept, cancel: cancel, placeholder: placeholder, submit: submit)
	}

	static func saveRecording(name: String, folder: Folder, url: URL) -> CommandEnum<Message> {
		return ._saveRecording(name: name, folder: folder, url: url)
	}
}


extension String {
	static let saveRecording = NSLocalizedString("Save recording", comment: "Heading for audio recording save dialog")
	static let save = NSLocalizedString("Save", comment: "Confirm button text for audio recoding save dialog")
	static let nameForRecording = NSLocalizedString("Name for recording", comment: "Placeholder for audio recording name text field")
}
