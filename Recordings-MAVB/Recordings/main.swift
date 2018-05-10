import UIKit

private let store = StoreAdapter(store: Store())
private let splitVar = Var<SplitState>(SplitState())

#if DEBUG
	let dl = store.logJson(prefix: "Document changed: ")
	let vl = splitVar.logJson(prefix: "View-state changed: ")
#endif

func application(_ splitVar: Var<SplitState>, _ store: StoreAdapter) -> Application {
	return Application(
		.window -- Window(
			.rootViewController <-- splitVar.map { splitState -> ViewControllerConvertible in
				splitView(splitState, store)
			}
		),
		.didEnterBackground --> Input().map { .save }.bind(to: store),
		.willEncodeRestorableState -- { archiver in archiver.encodeLatest(from: splitVar) },
		.didDecodeRestorableState -- { unarchiver in unarchiver.decodeSend(to: splitVar) }
	)
}

applicationMain { application(splitVar, store) }
