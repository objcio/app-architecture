import Foundation
import UIKit

private let formatter: DateComponentsFormatter = {
	let formatter = DateComponentsFormatter()
	formatter.unitsStyle = .positional
	formatter.zeroFormattingBehavior = .pad
	formatter.allowedUnits = [.hour, .minute, .second]
	return formatter
}()

func timeString(_ time: TimeInterval) -> String {
	return formatter.string(from: time)!
}
